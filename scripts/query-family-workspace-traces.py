"""Export real family initialization success and remote-write failure traces."""
import datetime
import importlib.util
import json
import os
from pathlib import Path
import time

spec = importlib.util.spec_from_file_location("skywalking_query", Path(__file__).with_name("query-skywalking.py"))
sw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sw)
out = Path(os.environ.get("OUT_DIR", "docs/reviews/evidence/2026-11-09-real-business"))


def main():
    found = {}
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline and len(found) < 2:
        start, end = sw.window(60)
        services = sw.services(start, end)
        for kind, service in (("success", "sf-business-auth"), ("remote-write-error", "sf-business-auth-fault")):
            if kind in found:
                continue
            item = next((item for item in services if item["name"] == service), None)
            if item is None:
                continue
            for trace in sw.traces_of(item["id"], start, end, 100):
                if not any("/families/workspaces" in name for name in trace["endpointNames"]):
                    continue
                if trace["isError"] != (kind != "success"):
                    continue
                trace_id = trace["traceIds"][0]
                spans = sw.trace_detail(trace_id)
                codes = {span["serviceCode"] for span in spans}
                fridge_write = any(span["serviceCode"] == "sf-business-fridge"
                    and "/fridges" in span["endpointName"] and span["type"] == "Entry"
                    and not span["isError"] for span in spans)
                database = any(span["layer"] == "Database" for span in spans)
                required = {service, "sf-business-fridge"}
                if kind == "success":
                    required.add("sf-business-gateway")
                if required <= codes and fridge_write and database:
                    found[kind] = {"traceId": trace_id, "isError": trace["isError"],
                        "services": sorted(codes), "spanCount": len(spans), "spans": spans}
                    print("PASS", kind, trace_id, sorted(codes), flush=True)
                    break
                # Ingestion of other segments may still be in progress. Retry.
        if len(found) < 2:
            time.sleep(5)
    out.mkdir(parents=True, exist_ok=True)
    for kind, result in found.items():
        (out / ("trace-workspace-" + kind + ".json")).write_text(
            json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    summary = {"queriedAt": datetime.datetime.now().astimezone().isoformat(),
        "passed": len(found) == 2, "traces": {kind: result["traceId"] for kind, result in found.items()}}
    (out / "trace-acceptance.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    if len(found) != 2:
        raise SystemExit("Missing complete family-workspace traces: " + str(set(("success", "remote-write-error")) - found.keys()))


if __name__ == "__main__":
    main()
