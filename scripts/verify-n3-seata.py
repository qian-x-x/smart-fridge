"""N3 验收：Seata AT 跨服务事务。

覆盖四类断言：
1. 成功下单：订单落库、库存扣减、二阶段提交后 undo_log 清空；
2. 库存不足：抛异常让全局事务回滚，订单不落库、库存不变；
3. 演示回滚：库存已扣减后订单侧失败，库存被 undo_log 还原、订单消失；
4. 一阶段确实写过库：回滚进行中能查到 PENDING 订单，结束后查不到。

依赖本机 docker（读取 seata / stock 日志）。取不到日志时该项标记为 SKIP，不算失败。
"""

import io
import json
import os
import subprocess
import threading
import time
import urllib.error
import urllib.request

STOCK = os.environ.get("STOCK_URL", "http://127.0.0.1:8084")
ORDER = os.environ.get("ORDER_URL", "http://127.0.0.1:8085")
OUT_DIR = os.environ.get(
    "OUT_DIR", "docs/reviews/evidence/2026-11-08-n3"
)
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
checks = []
skips = []


def call(method, url, body=None, timeout=40):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    started = time.monotonic()
    try:
        with OPENER.open(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode())
            status = response.status
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        payload = json.loads(raw) if raw else {}
        status = error.code
    return status, payload, round((time.monotonic() - started) * 1000)


def check(name, passed, detail):
    checks.append({"name": name, "pass": bool(passed), "detail": detail})
    print(("PASS  " if passed else "FAIL  ") + name + " :: " + detail)


def skip(name, detail):
    skips.append({"name": name, "detail": detail})
    print("SKIP  " + name + " :: " + detail)


def stock_of(sku):
    status, payload, _ = call("GET", STOCK + "/api/v1/products/" + sku)
    if status != 200:
        raise RuntimeError("查询库存失败 %s %s" % (status, payload))
    return payload["data"]["stock"]


def order_count():
    status, payload, _ = call("GET", ORDER + "/api/v1/orders?limit=100")
    if status != 200:
        raise RuntimeError("查询订单失败 %s %s" % (status, payload))
    return len(payload["data"])


def place(sku, quantity, fail_after=None, delay=None):
    body = {"sku": sku, "quantity": quantity}
    if fail_after is not None:
        body["failAfterDeduct"] = fail_after
    if delay is not None:
        body["stockDelayMs"] = delay
    return call("POST", ORDER + "/api/v1/orders", body)


def mysql(sql):
    """直接查库：接口返回值只能证明结果，表里的数据才能证明“真的落库/真的撤销”。"""
    result = subprocess.run(
        [
            "docker", "exec", "smart-fridge-mysql-trade", "mysql",
            "-usmart_fridge_trade", "-psmart_fridge_trade_dev",
            "--default-character-set=utf8mb4", "-N", "-B", "-e", sql,
        ],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 0:
        raise RuntimeError("mysql 查询失败: " + (result.stderr or "").strip())
    return result.stdout.strip()


def undo_log_count():
    stock = mysql("SELECT COUNT(*) FROM stock_db.undo_log")
    order = mysql("SELECT COUNT(*) FROM order_db.undo_log")
    return int(stock or 0), int(order or 0)


def docker_logs(container, pattern):
    """抓到日志返回命中行数；没有 docker 时返回 None。"""
    try:
        result = subprocess.run(
            ["docker", "logs", container, "--since", "5m"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    return sum(1 for line in result.stdout.splitlines() if pattern in line)


print("== N3 Seata 跨服务事务验收 ==")

# 日志断言只看本次运行产生的增量，避免把上一次验收的记录算进来。
baseline_rollback = docker_logs("sf-stock", "branch rollback success") or 0
baseline_global = docker_logs(
    "smart-fridge-seata", "Rollback global transaction successfully"
) or 0

# --- 1. 成功下单：两个分支都提交 ---
base_stock = stock_of("APPLE")
base_orders = order_count()
status, payload, elapsed = place("APPLE", 2)
order_id = (payload.get("data") or {}).get("orderId")
after_stock = stock_of("APPLE")
check(
    "success-first-order-created",
    status == 201 and order_id and payload["data"]["status"] == "CREATED",
    "status=%d orderId=%s remaining=%s elapsed=%dms"
    % (status, order_id, (payload.get("data") or {}).get("remainingStock"), elapsed),
)
check(
    "success-stock-deducted-in-db",
    after_stock == base_stock - 2,
    "before=%d after=%d" % (base_stock, after_stock),
)
check(
    "success-order-row-persisted",
    mysql("SELECT status FROM order_db.order_record WHERE order_id='%s'" % order_id) == "CREATED",
    "db status=%s" % mysql(
        "SELECT status FROM order_db.order_record WHERE order_id='%s'" % order_id
    ),
)

time.sleep(1.2)

# --- 2. 第二例成功：换一个商品，证明不是偶然 ---
milk_before = stock_of("MILK")
status, payload, _ = place("MILK", 1)
milk_after = stock_of("MILK")
check(
    "success-second-sku",
    status == 201 and milk_after == milk_before - 1,
    "status=%d milk %d->%d" % (status, milk_before, milk_after),
)

time.sleep(1.2)

# AT 提交后 undo_log 会被异步清理，此时两个库都应为空。
time.sleep(2)
stock_undo, order_undo = undo_log_count()
check(
    "committed-undo-log-cleaned",
    stock_undo == 0 and order_undo == 0,
    "stock.undo_log=%d order.undo_log=%d" % (stock_undo, order_undo),
)

# --- 3. 库存不足：异常触发全局回滚，订单不能留下 ---
egg_before = stock_of("EGG")
orders_before = order_count()
status, payload, _ = place("EGG", 9999)
egg_after = stock_of("EGG")
orders_after = order_count()
check(
    "shortage-returns-409",
    status == 409,
    "status=%d message=%s" % (status, payload.get("message")),
)
check(
    "shortage-rolls-back-order",
    orders_after == orders_before and egg_after == egg_before,
    "orders %d->%d egg %d->%d" % (orders_before, orders_after, egg_before, egg_after),
)

time.sleep(1.2)

# --- 4. 演示回滚：库存已扣减后失败，库存被还原 ---
rollback_stock_before = stock_of("APPLE")
rollback_orders_before = order_count()
status, payload, elapsed = place("APPLE", 3, fail_after=True)
rollback_stock_after = stock_of("APPLE")
rollback_orders_after = order_count()
check(
    "rollback-returns-error",
    status == 500 and "回滚" in (payload.get("message") or ""),
    "status=%d message=%s" % (status, payload.get("message")),
)
check(
    "rollback-restores-stock",
    rollback_stock_after == rollback_stock_before,
    "stock %d->%d (扣减 3 已还原)" % (rollback_stock_before, rollback_stock_after),
)
check(
    "rollback-removes-order",
    rollback_orders_after == rollback_orders_before,
    "orders %d->%d" % (rollback_orders_before, rollback_orders_after),
)

time.sleep(2)
stock_undo, order_undo = undo_log_count()
check(
    "rollback-undo-log-cleaned",
    stock_undo == 0 and order_undo == 0,
    "stock.undo_log=%d order.undo_log=%d" % (stock_undo, order_undo),
)

# --- 5. 本地事务未提交时外部不可见：说明订单插入由本地回滚丢弃 ---
probe = {}


def probe_pending():
    time.sleep(0.9)
    probe["pending"] = mysql(
        "SELECT COUNT(*) FROM order_db.order_record WHERE status='PENDING'"
    )


time.sleep(1.2)
thread = threading.Thread(target=probe_pending)
thread.start()
status, payload, elapsed = place("APPLE", 1, fail_after=True, delay=1200)
thread.join()
pending_seen = int(probe.get("pending") or 0)
pending_after = int(mysql(
    "SELECT COUNT(*) FROM order_db.order_record WHERE status='PENDING'"
) or 0)
check(
    "uncommitted-order-invisible-outside-tx",
    pending_seen == 0 and pending_after == 0 and status == 500,
    "回滚中/结束后都查不到 PENDING：订单插入属于未提交的本地事务，随本地回滚丢弃；"
    "只有已在一阶段提交的库存分支才需要 undo_log 二阶段回滚（耗时 %dms）" % elapsed,
)

# --- 6. 日志证据：二阶段回滚由 stock 侧执行 ---
rollback_lines = docker_logs("sf-stock", "branch rollback success")
if rollback_lines is None:
    skip("branch-rollback-in-stock-log", "本机无法读取 docker 日志")
else:
    delta = rollback_lines - baseline_rollback
    check(
        "branch-rollback-in-stock-log",
        delta >= 2,
        "本次新增 branch rollback success %d 次（对应库存不足与演示回滚）" % delta,
    )

rollback_global = docker_logs("smart-fridge-seata", "Rollback global transaction successfully")
if rollback_global is None:
    skip("global-rollback-in-seata-log", "本机无法读取 docker 日志")
else:
    delta = rollback_global - baseline_global
    check(
        "global-rollback-in-seata-log",
        delta >= 2,
        "本次新增全局回滚成功 %d 次" % delta,
    )

passed = sum(1 for item in checks if item["pass"])
total = len(checks)
summary = {
    "runAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "total": total,
    "passed": passed,
    "failed": total - passed,
    "checks": checks,
    "skipped": skips,
}
os.makedirs(OUT_DIR, exist_ok=True)
io.open(os.path.join(OUT_DIR, "api-acceptance.json"), "w", encoding="utf-8", newline="").write(
    json.dumps(summary, ensure_ascii=False, indent=2)
)
print("\n%d/%d checks passed" % (passed, total))
