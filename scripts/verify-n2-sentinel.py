import json
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

GW = "http://127.0.0.1:8080"
ORDER = "http://127.0.0.1:8085"
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
checks = []


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    started = time.monotonic()
    try:
        with OPENER.open(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode())
            status = resp.status
    except urllib.error.HTTPError as error:
        payload = json.loads(error.read().decode() or "{}")
        status = error.code
    return status, payload, round((time.monotonic() - started) * 1000)


def check(name, passed, detail):
    checks.append({"name": name, "pass": passed, "detail": detail})
    print(("PASS  " if passed else "FAIL  ") + name + " :: " + detail)


def place(quantity=1, delay=None):
    body = {"sku": "APPLE", "quantity": quantity}
    if delay is not None:
        body["stockDelayMs"] = delay
    return call("POST", ORDER + "/api/v1/orders", body)


print("== N2 超时 / 熔断 / 流控验收 ==")

# --- C3：调用超时与错误传播 ---
status, payload, elapsed = place(1, 3000)
check(
    "c3-timeout-returns-explicit-error",
    status == 503 and "超时" in json.dumps(payload, ensure_ascii=False) and elapsed < 2500,
    "status=%d elapsed=%dms message=%s" % (status, elapsed, payload.get("message")),
)

time.sleep(12)  # 让慢调用统计窗口翻篇

# --- C2：慢调用比例熔断 ---
slow_results = []
for index in range(2):
    status, payload, elapsed = place(1, 800)
    slow_results.append({"status": status, "elapsed": elapsed})
    time.sleep(1.2)  # 低于 QPS=2，避免误触流控

status, payload, elapsed = place(1, 800)
blocked = status == 503 and "熔断" in json.dumps(payload, ensure_ascii=False)
check(
    "c2-circuit-breaker-opens",
    all(item["status"] == 201 for item in slow_results) and blocked,
    "slow=%s then status=%d elapsed=%dms message=%s"
    % (slow_results, status, elapsed, payload.get("message")),
)
check(
    "c2-blocked-call-skips-downstream",
    elapsed < 300,
    "blocked elapsed=%dms（远小于 800ms 的慢调用，说明没有再发起真实请求）" % elapsed,
)

time.sleep(11)  # 熔断窗口结束，进入半开

status, payload, elapsed = place(1)
check(
    "c2-recovers-after-window",
    status == 201,
    "status=%d elapsed=%dms remaining=%s"
    % (status, elapsed, (payload.get("data") or {}).get("remainingStock")),
)

time.sleep(3)

# --- C2：QPS 流控（并发触发）---
with ThreadPoolExecutor(max_workers=6) as pool:
    burst = [future.result() for future in
             [pool.submit(place, 1) for _ in range(6)]]

statuses = [item[0] for item in burst]
limited = [item for item in burst if item[0] == 429]
check(
    "c2-flow-control-blocks-burst",
    len(limited) >= 1,
    "statuses=%s" % statuses,
)
if limited:
    check(
        "c2-rate-limit-message-readable",
        "过于频繁" in json.dumps(limited[0][1], ensure_ascii=False),
        "message=%s" % limited[0][1].get("message"),
    )

summary = {
    "runAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "orderService": ORDER,
    "total": len(checks),
    "passed": sum(1 for item in checks if item["pass"]),
    "failed": sum(1 for item in checks if not item["pass"]),
    "checks": checks,
}
with open("docs/reviews/evidence/2026-11-08-n2/api-acceptance.json", "w", encoding="utf-8") as handle:
    json.dump(summary, handle, ensure_ascii=False, indent=2)

print("\n== %d/%d checks passed ==" % (summary["passed"], summary["total"]))
