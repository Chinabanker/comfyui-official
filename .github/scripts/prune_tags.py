#!/usr/bin/env python3
"""Delete dated image tags older than the newest N on Docker Hub (retention).

Auth: exchanges the Docker Hub PAT for a short-lived JWT (PATs cannot be used
as bearer directly). NOTE: tag DELETE requires an Account-scope PAT; a
Read&Write PAT will hit 403 -> retention is skipped with a warning (build/push
still succeed).
"""
import json
import os
import sys
import urllib.request
import urllib.error

NS = "chinabanker"
REPO = "comfyui-official"
KEEP = int(os.environ.get("KEEP_DATED_TAGS", "7"))
PREFIX = "cu128-"


def exchange_jwt(pat: str) -> str:
    req = urllib.request.Request(
        "https://hub.docker.com/v2/auth/token",
        data=json.dumps({"identifier": NS, "secret": pat}).encode(),
        headers={"Content-Type": "application/json"}, method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    jwt = d.get("access_token") or d.get("token")
    if not jwt:
        raise RuntimeError(f"no token in auth response: {list(d.keys())}")
    return jwt


def api(path, method="GET"):
    req = urllib.request.Request(
        f"https://hub.docker.com/v2/repositories/{NS}/{REPO}/{path}",
        method=method,
        headers={"Authorization": f"Bearer {JWT}"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r) if r.status == 200 else None


def main():
    global JWT
    pat = os.environ["DH_TOKEN"]
    try:
        JWT = exchange_jwt(pat)
    except Exception as e:
        print(f"auth failed: {e}")
        sys.exit(1)

    try:
        tags = api("tags?page_size=100").get("results", [])
    except urllib.error.HTTPError as e:
        print(f"list tags failed: {e.code} {e.read().decode()[:200]}")
        sys.exit(1)

    dated = sorted(
        (t["name"] for t in tags if t["name"].startswith(PREFIX)),
        reverse=True,
    )
    to_delete = dated[KEEP:]
    print(f"retention: {len(dated)} dated tags, keeping newest {KEEP}, deleting {len(to_delete)}")
    for name in to_delete:
        try:
            api(f"tags/{name}", "DELETE")
            print(f"  deleted {name}")
        except urllib.error.HTTPError as e:
            if e.code == 403:
                print("WARNING: tag DELETE requires an Account-scope PAT "
                      f"(Read&Write got 403) — retention skipped, keeping {name}.")
                print("Create an Account-scope token at hub.docker.com/settings/security "
                      "and update the DOCKERHUB_TOKEN secret to enable retention.")
                sys.exit(0)
            print(f"  skip {name}: {e.code} {e.read().decode()[:120]}")


if __name__ == "__main__":
    main()
