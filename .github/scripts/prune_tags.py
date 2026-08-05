#!/usr/bin/env python3
"""Delete dated image tags older than the newest N on Docker Hub (retention)."""
import json
import os
import sys
import urllib.request
import urllib.error

NS = "chinabanker"
REPO = "comfyui-official"
KEEP = int(os.environ.get("KEEP_DATED_TAGS", "7"))
PREFIX = "cu128-"


def api(path, method="GET"):
    tok = os.environ["DH_TOKEN"]
    req = urllib.request.Request(
        f"https://hub.docker.com/v2/repositories/{NS}/{REPO}/{path}",
        method=method,
        headers={"Authorization": f"Bearer {tok}"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r) if r.status == 200 else None


def main():
    try:
        tags = api("tags?page_size=100&ordering=last_updated").get("results", [])
    except urllib.error.HTTPError as e:
        print(f"list tags failed: {e.code} {e.read().decode()[:200]}")
        sys.exit(1)

    dated = sorted(
        (t["name"] for t in tags if t["name"].startswith(PREFIX)),
        reverse=True,
    )
    for name in dated[KEEP:]:
        try:
            api(f"tags/{name}", "DELETE")
            print(f"deleted {name}")
        except Exception as e:
            print(f"skip {name}: {e}")
    print(f"retention done: keeping newest {KEEP} dated tags, {len(dated)} existed")


if __name__ == "__main__":
    main()
