"""查询 SkyWalking：服务列表、下单链路 Trace 与 span 明细，并导出证据。

用法：
    python scripts/query-skywalking.py            # 最近 15 分钟，自动找下单链路
    python scripts/query-skywalking.py --minutes 60

注意：OAP 容器必须与服务端同时区（启动时加 `-e TZ=Asia/Shanghai`），
否则 GraphQL 的时间窗口会差 8 小时，查不到任何 trace。
"""

import argparse
import datetime
import io
import json
import os
import urllib.request

OAP = os.environ.get("SW_OAP", "http://127.0.0.1:12800/graphql")
OUT_DIR = os.environ.get("OUT_DIR", "docs/reviews/evidence/2026-11-08-n4")
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def gql(query):
    body = json.dumps({"query": query}).encode()
    request = urllib.request.Request(OAP, data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    with OPENER.open(request, timeout=30) as response:
        payload = json.loads(response.read().decode())
    if "errors" in payload:
        raise RuntimeError(payload["errors"])
    return payload["data"]


def window(minutes):
    now = datetime.datetime.now()
    start = (now - datetime.timedelta(minutes=minutes)).strftime("%Y-%m-%d %H%M")
    end = (now + datetime.timedelta(minutes=2)).strftime("%Y-%m-%d %H%M")
    return start, end


def services(start, end):
    return gql(
        'query { getAllServices(duration: {start: "%s", end: "%s", step: MINUTE}) '
        "{ id name group } }" % (start, end)
    )["getAllServices"]


def traces_of(service_id, start, end, size=20):
    return gql(
        'query { queryBasicTraces(condition: {serviceId: "%s", '
        'queryDuration: {start: "%s", end: "%s", step: MINUTE}, '
        "traceState: ALL, queryOrder: BY_START_TIME, paging: {pageNum: 1, pageSize: %d}}) "
        "{ traces { traceIds endpointNames duration start isError } } }"
        % (service_id, start, end, size)
    )["queryBasicTraces"]["traces"]


def trace_detail(trace_id):
    return gql(
        'query { queryTrace(traceId: "%s") { spans { traceId segmentId spanId parentSpanId '
        "refs { traceId parentSegmentId parentSpanId type } serviceCode serviceInstanceName "
        "startTime endTime endpointName type peer component isError layer "
        "tags { key value } } } }" % trace_id
    )["queryTrace"]["spans"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--minutes", type=int, default=15)
    parser.add_argument(
        "--error",
        action="store_true",
        help="导出失败链路（下单接口 failAfterDeduct=true 触发），用于演示按 Trace 定位问题",
    )
    args = parser.parse_args()

    start, end = window(args.minutes)
    print("窗口:", start, "->", end)

    items = services(start, end)
    print("已上报服务:", ", ".join(sorted({"服务=" + s["name"] if not s["name"].count(":")
                                          else "依赖=" + s["name"] for s in items})))

    order = next((s for s in items if s["name"] == "order-service"), None)
    if order is None:
        raise SystemExit("OAP 里没有 order-service，确认 agent 已挂载且 backend_service 指向 skywalking-oap:11800")

    candidates = [
        trace
        for trace in traces_of(order["id"], start, end)
        if any("orders" in name for name in trace["endpointNames"])
    ]
    if not candidates:
        raise SystemExit("没有下单链路的 trace；先调用一次 POST /api/v1/orders")

    if args.error:
        candidates = [trace for trace in candidates if trace["isError"]] or candidates
        success = candidates[0]
        print("\n（失败链路模式）")
    else:
        success = next((t for t in candidates if not t["isError"]), candidates[0])
    trace_id = success["traceIds"][0]
    spans = sorted(trace_detail(trace_id), key=lambda span: (span["startTime"], span["spanId"]))

    print("\n下单链路 traceId:", trace_id)
    base = min(span["startTime"] for span in spans)
    for span in spans:
        offset = span["startTime"] - base
        print(
            "  +%-4dms [%-10s] %-22s %-42s peer=%-18s component=%s error=%s"
            % (
                offset,
                span["layer"],
                span["serviceCode"],
                span["endpointName"],
                span["peer"] or "-",
                span["component"] or "-",
                span["isError"],
            )
        )

    summary = {
        "queriedAt": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "window": {"start": start, "end": end},
        "services": [{"id": s["id"], "name": s["name"]} for s in items],
        "traceId": trace_id,
        "totalDurationMs": max(span["endTime"] for span in spans) - base,
        "spanCount": len(spans),
        "spans": spans,
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "trace-error.json" if args.error else "trace-order.json")
    io.open(path, "w", encoding="utf-8", newline="").write(
        json.dumps(summary, ensure_ascii=False, indent=2)
    )
    print("\n证据已写入", path)


if __name__ == "__main__":
    main()
