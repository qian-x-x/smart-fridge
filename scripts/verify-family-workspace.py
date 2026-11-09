"""Real user business acceptance: Gateway + Feign + Sentinel + Seata + MySQL.

Run Start-BusinessAcceptance.ps1 first. Faults live in an isolated test proxy,
never in product request parameters. Existing development schemas are untouched.
"""
import concurrent.futures
import datetime
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid

sys.stdout.reconfigure(encoding="utf-8")
BASE = os.environ.get("BUSINESS_GATEWAY", "http://127.0.0.1:18080")
FAULT = "http://127.0.0.1:18091"
PROXY = "http://127.0.0.1:18089"
OUT = Path(os.environ.get("OUT_DIR", "docs/reviews/evidence/2026-11-09-real-business"))
RUN = uuid.uuid4().hex[:10]
CHECKS = []
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def check(name, passed, detail=""):
    CHECKS.append({"name": name, "pass": bool(passed), "detail": detail})
    print(("PASS " if passed else "FAIL ") + name + " " + str(detail), flush=True)
    if not passed:
        raise AssertionError(name)


def call(path, token=None, body=None, base=BASE, headers=None):
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
    request = urllib.request.Request(base + path, data=data,
        headers={"Content-Type": "application/json", **({"Authorization": "Bearer " + token} if token else {}),
                 **(headers or {})})
    start = time.monotonic()
    try:
        response = OPENER.open(request, timeout=35)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        payload = json.loads(response.read().decode())
        return response.status, payload, round((time.monotonic() - start) * 1000)


def sql(database, statement):
    if database not in {"auth_business", "fridge_business"}:
        raise ValueError("only dedicated acceptance schemas are allowed")
    result = subprocess.run(["docker", "exec", "-e", "MYSQL_PWD=smart_fridge_root_dev",
        "smart-fridge-mysql-core", "mysql", "-uroot", "-N", "-B",
        "--default-character-set=utf8mb4", database, "-e", statement],
        check=True, capture_output=True, text=True, encoding="utf-8")
    return result.stdout.strip()


def counts():
    return tuple(int(sql(db, "SELECT COUNT(*) FROM " + table))
        for db, table in [("auth_business", "family"), ("auth_business", "family_member"),
            ("auth_business", "family_workspace_request"), ("fridge_business", "fridge"),
            ("fridge_business", "fridge_zone"), ("fridge_business", "fridge_container")])


def mode(value):
    assert call("/__test__/mode", body={"mode": value}, base=PROXY)[0] == 200


def workspace(token, key, name, base=BASE):
    return call("/api/v1/families/workspaces", token,
        {"requestId": key, "name": name}, base=base,
        headers={"X-User-Id": "999999",
            **({"TX_XID": "untrusted-caller-xid"} if base == BASE else {})})


def register(suffix):
    username = "business_" + RUN + suffix
    password = "Business2026!"
    status, payload, _ = call("/api/v1/auth/register", body={
        "username": username, "displayName": "业务验收用户", "password": password})
    check("register-" + suffix, status == 201, f"http={status}")
    return payload["data"]["accessToken"], username, password, payload["data"]["user"]["id"]


def wait_rollback(before, name):
    deadline = time.monotonic() + 12
    current = None
    while time.monotonic() < deadline:
        current = counts()
        if current == before:
            break
        time.sleep(0.3)
    check(name, current == before, f"before={before}; after={current}")


def main():
    token, username, password, user_id = register("owner")
    other, _, _, other_id = register("other")
    # Separate, ignored context for browser login; evidence never stores tokens.
    Path("output/real-business").mkdir(parents=True, exist_ok=True)
    Path("output/real-business/ui-context.json").write_text(json.dumps({
        "username": username, "password": password, "familyName": "界面家庭_" + RUN,
        "base": BASE}, ensure_ascii=False), encoding="utf-8")
    key = RUN + "-shared"
    for index, access in enumerate((token, other), start=1):
        status, body, elapsed = workspace(access, key, "实际家庭_" + RUN + str(index))
        check(f"success-{index}", status == 201, f"http={status}, ms={elapsed}")
        data = body["data"]
        family_id, fridge_id = data["family"]["id"], data["fridgeId"]
        check(f"owner-member-{index}", int(sql("auth_business",
            f"SELECT COUNT(*) FROM family_member WHERE family_id={family_id} AND role='OWNER'")) == 1)
        status, fridge, _ = call("/api/v1/fridges?familyId=" + str(family_id), access)
        zones = fridge.get("data", {}).get("zones", [])
        check(f"usable-fridge-{index}", status == 200 and fridge["data"]["id"] == fridge_id
            and len(zones) == 4 and sum(len(zone["containers"]) for zone in zones) == 6,
            f"fridge={fridge_id}, zones={len(zones)}")
        if index == 1:
            owner_workspace = data
    status, replay, _ = workspace(token, key, "实际家庭_" + RUN + "1")
    check("committed-replay", status == 200 and replay["data"] == owner_workspace)
    check("request-scoped-per-user", int(sql("auth_business",
        f"SELECT COUNT(*) FROM family_workspace_request WHERE request_id='{key}'")) == 2,
        f"user ids {user_id}/{other_id} each created their own workspace")
    check("changed-payload-conflict", workspace(token, key, "更改名称")[0] == 409)
    xid = sql("auth_business", f"SELECT xid FROM family_workspace_request WHERE actor_user_id={user_id} AND request_id='{key}'")
    check("backend-created-xid", ":8091:" in xid and "untrusted" not in xid)
    fridge_id = owner_workspace["fridgeId"]
    family_id = owner_workspace["family"]["id"]
    check("stranger-cannot-read-fridge", call(f"/api/v1/fridges/{fridge_id}", other)[0] in (403, 404))
    check("unauthenticated-write-denied", workspace(None, RUN + "-noauth", "无令牌家庭")[0] == 401)
    check("invalid-request-denied", workspace(token, "bad", "家庭")[0] == 400)
    _, fridge, _ = call(f"/api/v1/fridges/{fridge_id}", token)
    zone = fridge["data"]["zones"][0]
    today = datetime.date.today()
    food = {"fridgeId": fridge_id, "zoneId": zone["id"], "containerId": zone["containers"][0]["id"],
        "name": "初始化后牛奶", "category": "奶制品", "quantity": 2, "unit": "盒",
        "productionDate": str(today), "expiresOn": str(today + datetime.timedelta(days=3)),
        "tags": [], "modelKey": "milk"}
    status, added, _ = call("/api/v1/foods", token, food)
    check("created-workspace-accepts-real-food", status == 201 and added["data"]["quantity"] == 2)
    join_status, _, _ = call("/api/v1/families/join", other,
        {"inviteCode": owner_workspace["family"]["inviteCode"]})
    check("family-collaboration-still-works", join_status == 200)
    check("viewer-cannot-write", call("/api/v1/foods", other, food)[0] == 403)

    # Warm the fault-only caller. Its name/group cannot affect the normal route.
    mode("healthy")
    for attempt in range(4):
        status, _, _ = workspace(token, RUN + "-fault-warm", "预热家庭_" + RUN, FAULT)
        if status in (200, 201):
            break
        time.sleep(11)
    check("fault-fixture-ready", status in (200, 201))
    for failure in ("reject", "lose-response", "timeout"):
        time.sleep(11)  # Independent circuit windows; no stale test state.
        before = counts()
        forwarded = call("/", base=PROXY)[1]["forwarded"]
        mode(failure)
        status, _, elapsed = workspace(token, RUN + "-" + failure, "异常家庭_" + RUN + failure, FAULT)
        check("failure-http-" + failure, status == 503, f"http={status}, ms={elapsed}")
        if failure == "timeout":
            time.sleep(3)
        if failure != "reject":
            check("remote-actually-called-" + failure,
                call("/", base=PROXY)[1]["forwarded"] == forwarded + 1)
        wait_rollback(before, "atomic-rollback-" + failure)
        check("rolled-back-request-key-" + failure, int(sql("auth_business",
            f"SELECT COUNT(*) FROM family_workspace_request WHERE actor_user_id={user_id} AND request_id='{RUN}-{failure}'")) == 0)
        mode("healthy")
    time.sleep(11)
    status, _, _ = workspace(token, RUN + "-lose-response", "异常家庭_" + RUN + "lose-response", FAULT)
    check("retry-after-rollback", status == 201)

    time.sleep(11)
    mode("slow")
    for index in range(2):
        status, _, elapsed = workspace(token, RUN + "-slow" + str(index), "慢调用家庭_" + RUN + str(index), FAULT)
        check("slow-real-write-" + str(index), status == 201, f"ms={elapsed}")
    before = counts()
    forwarded = call("/", base=PROXY)[1]["forwarded"]
    status, _, elapsed = workspace(token, RUN + "-circuit", "熔断家庭_" + RUN, FAULT)
    check("circuit-opens", status == 503, f"ms={elapsed}")
    check("circuit-skips-downstream", call("/", base=PROXY)[1]["forwarded"] == forwarded)
    wait_rollback(before, "circuit-does-not-leave-family")
    mode("healthy")
    time.sleep(11)
    check("circuit-recovers", workspace(token, RUN + "-recover", "恢复家庭_" + RUN, FAULT)[0] == 201)

    time.sleep(1.2)
    barrier = threading.Barrier(13)
    def burst(index):
        barrier.wait()
        return workspace(token, RUN + "-burst" + str(index), "并发家庭_" + RUN + str(index))[0]
    before = counts()
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as executor:
        futures = [executor.submit(burst, index) for index in range(12)]
        barrier.wait()
        statuses = [future.result() for future in futures]
    check("flow-control-real-entry", 429 in statuses and 201 in statuses and set(statuses) <= {201, 429}, statuses)
    after = counts()
    successes = statuses.count(201)
    check("limited-requests-leave-no-partial-data",
        tuple(b + successes * factor for b, factor in zip(before, (1, 1, 1, 1, 4, 6))) == after,
        f"successful={successes}; before={before}; after={after}")

    time.sleep(1.2)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        statuses = list(executor.map(lambda _: workspace(token, RUN + "-race", "同请求家庭_" + RUN)[0], range(4)))
    time.sleep(1.2)
    status, _, _ = workspace(token, RUN + "-race", "同请求家庭_" + RUN)
    check("concurrent-idempotent-replay", statuses.count(201) == 1
        and set(statuses) <= {200, 201, 409, 429} and status == 200, statuses)
    check("concurrent-single-workspace", int(sql("auth_business",
        f"SELECT COUNT(*) FROM family_workspace_request WHERE actor_user_id={user_id} AND request_id='{RUN}-race'")) == 1)
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        pending = [int(sql(db, "SELECT COUNT(*) FROM undo_log")) for db in ("auth_business", "fridge_business")]
        if pending == [0, 0]:
            break
        time.sleep(0.3)
    check("both-undo-logs-drained", pending == [0, 0], pending)
    return {"runId": RUN, "gateway": BASE, "schemas": ["auth_business", "fridge_business"],
        "successWorkspace": owner_workspace}


if __name__ == "__main__":
    metadata = {}
    failure = None
    try:
        metadata = main()
    except Exception as error:
        failure = str(error)
        print("ACCEPTANCE FAILED:", type(error).__name__, failure, flush=True)
    finally:
        try:
            mode("healthy")
        except Exception:
            pass
        OUT.mkdir(parents=True, exist_ok=True)
        result = {**metadata, "runAt": datetime.datetime.now().astimezone().isoformat(),
            "checks": CHECKS, "passed": sum(item["pass"] for item in CHECKS),
            "total": len(CHECKS), "error": failure}
        (OUT / "api-acceptance.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    sys.exit(1 if failure or not CHECKS or not all(item["pass"] for item in CHECKS) else 0)
