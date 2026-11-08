"""N4 验收：SkyWalking 链路追踪。

断言三件事：
1. 6 个业务服务都向 OAP 上报（说明 agent 全部挂载成功）；
2. 一次真实下单产生跨 4 个服务的完整链路（gateway → auth 校验 → order → stock）；
3. 链路里能看到 Feign、MySQL、Redis 三类依赖节点，可作为"按 Trace 排查"的依据。

用法：python scripts/verify-n4-skywalking.py
"""

import datetime
import io
import json
import os
import time
import urllib.error
import urllib.request

GW = os.environ.get("GATEWAY_URL", "http://127.0.0.1:8080")
OAP = os.environ.get("SW_OAP", "http://127.0.0.1:12800/graphql")
OUT_DIR = os.environ.get("OUT_DIR", "docs/reviews/evidence/2026-11-08-n4")
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
checks = []

EXPECTED_SERVICES = [
    "gateway-service",
    "auth-family-service",
    "fridge-service",
    "recipe-service",
    "stock-service",
    "order-service",
]


def check(name, passed, detail):
    checks.append({"name": name, "pass": bool(passed), "detail": detail})
    print(("PASS  " if passed else "FAIL  ") + name + " :: " + detail)


def http(method, url, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    request.add_header("Content-Type", "application/json")
    try:
        with OPENER.open(request, timeout=30) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        return error.code, (json.loads(raw) if raw else {})


def gql(query):
    request = urllib.request.Request(
        OAP, data=json.dumps({"query": query}).encode(), method="POST"
    )
    request.add_header("Content-Type", "application/json")
    with OPENER.open(request, timeout=30) as response:
        payload = json.loads(response.read().decode())
    if "errors" in payload:
        raise RuntimeError(payload["errors"])
    return payload["data"]


def window(minutes):
    now = datetime.datetime.now()
    return (
        (now - datetime.timedelta(minutes=minutes)).strftime("%Y-%m-%d %H%M"),
        (now + datetime.timedelta(minutes=3)).strftime("%Y-%m-%d %H%M"),
    )


def services(start, end):
    return gql(
        'query { getAllServices(duration: {start: "%s", end: "%s", step: MINUTE}) { id name } }'
        % (start, end)
    )["getAllServices"]


print("== N4 SkyWalking 链路追踪验收 ==")

# --- 0. OAP 可达 ---
try:
    start, end = window(20)
    items = services(start, end)
    check("oap-reachable", True, "窗口 %s -> %s，已上报 %d 个服务/依赖" % (start, end, len(items)))
except Exception as error:  # noqa: BLE001
    check("oap-reachable", False, repr(error))
    raise SystemExit(1)

# --- 1. 6 个业务服务全部上报 ---
# OAP 刚重启时 agent 的注册心跳还没到齐，这里最多等 90 秒再判定。
names = {item["name"] for item in items}
for _ in range(6):
    missing = [name for name in EXPECTED_SERVICES if name not in names]
    if not missing:
        break
    time.sleep(15)
    start, end = window(20)
    items = services(start, end)
    names = {item["name"] for item in items}

missing = [name for name in EXPECTED_SERVICES if name not in names]
check(
    "all-six-services-reported",
    not missing,
    "已上报 %d/6，缺失 %s" % (len(EXPECTED_SERVICES) - len(missing), missing or "无"),
)

# --- 2. 依赖被发现（MySQL / Redis 作为对端节点） ---
deps = sorted(name for name in names if ":" in name)
check(
    "dependencies-discovered",
    any("mysql" in dep for dep in deps) and any("redis" in dep for dep in deps),
    "依赖节点：" + ", ".join(deps),
)

# --- 3. 触发一次真实下单 ---
status, payload = http(
    "POST", GW + "/api/v1/auth/login",
    {"identifier": os.environ.get("E2E_USER", "ui020247"),
     "password": os.environ.get("E2E_PASS", "Accept2026!")},
)
token = (payload.get("data") or {}).get("accessToken")
check("login-for-trace", status == 200 and bool(token), "status=%d" % status)

status, payload = http(
    "POST", GW + "/api/v1/orders",
    {"sku": "EGG", "quantity": 1},
    {"Authorization": "Bearer " + token},
)
check(
    "order-created-for-trace",
    status == 201,
    "status=%d orderId=%s" % (status, (payload.get("data") or {}).get("orderId")),
)

# --- 4. 等 OAP 收齐，找这条下单链路 ---
trace = None
for attempt in range(6):
    time.sleep(12)
    start, end = window(25)
    items = services(start, end)
    order = next((item for item in items if item["name"] == "order-service"), None)
    if order is None:
        continue
    traces = gql(
        'query { queryBasicTraces(condition: {serviceId: "%s", '
        'queryDuration: {start: "%s", end: "%s", step: MINUTE}, '
        'traceState: ALL, queryOrder: BY_START_TIME, paging: {pageNum: 1, pageSize: 20}}) '
        "{ traces { traceIds endpointNames duration isError } } }"
        % (order["id"], start, end)
    )["queryBasicTraces"]["traces"]
    candidates = [
        item for item in traces
        if any("orders" in name for name in item["endpointNames"]) and not item["isError"]
    ]
    if candidates:
        trace = candidates[0]
        break

if trace is None:
    check("trace-captured", False, "等待 72 秒仍没有下单链路，检查 agent 与采样率")
    raise SystemExit(1)

check("trace-captured", True, "traceId=%s" % trace["traceIds"][0])

spans = gql(
    'query { queryTrace(traceId: "%s") { spans { serviceCode endpointName layer peer '
    "component isError startTime endTime } } }" % trace["traceIds"][0]
)["queryTrace"]["spans"]

span_services = sorted({span["serviceCode"] for span in spans})
base = min(span["startTime"] for span in spans)
total_ms = max(span["endTime"] for span in spans) - base

check(
    "trace-crosses-four-services",
    {"gateway-service", "auth-family-service", "order-service", "stock-service"} <= set(span_services),
    "覆盖服务：%s" % ", ".join(span_services),
)
check("trace-span-count", len(spans) >= 20, "%d 个 span，总耗时 %dms" % (len(spans), total_ms))
check(
    "trace-has-gateway-entry",
    any(s["serviceCode"] == "gateway-service" and "/api/v1/orders" in s["endpointName"] for s in spans),
    "网关入口 span 存在（Spring Cloud Gateway 插件）",
)
check(
    "trace-has-feign-hop",
    any(s["component"] == "Feign" for s in spans),
    "Feign 跨服务节点："
    + ", ".join(sorted({s["endpointName"] for s in spans if s["component"] == "Feign"})),
)
check(
    "trace-has-mysql-and-redis",
    any(s["layer"] == "Database" and "mysql" in (s["peer"] or "") for s in spans)
    and any(s["layer"] == "Cache" and "redis" in (s["peer"] or "") for s in spans),
    "MySQL 与 Redis 节点均在链路中",
)

summary = {
    "runAt": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
    "oap": OAP,
    "traceId": trace["traceIds"][0],
    "totalDurationMs": total_ms,
    "spanCount": len(spans),
    "services": span_services,
    "reportedServices": sorted(names),
    "checks": checks,
    "passed": sum(1 for item in checks if item["pass"]),
    "total": len(checks),
}
os.makedirs(OUT_DIR, exist_ok=True)
io.open(os.path.join(OUT_DIR, "api-acceptance.json"), "w", encoding="utf-8", newline="").write(
    json.dumps(summary, ensure_ascii=False, indent=2)
)
print("\n%d/%d checks passed" % (summary["passed"], summary["total"]))
