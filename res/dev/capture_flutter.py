#!/usr/bin/env python3
"""Capture a debug Flutter view without relying on X11 screenshots on Wayland."""
import argparse
import base64
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--log", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--isolate", type=int, default=0)
parser.add_argument("--inspector", action="store_true")
args = parser.parse_args()
# Keep the VM service authentication URL in memory; never print it.
endpoints = re.findall(
    r"The Dart VM service is listening on (http://127\.0\.0\.1:\d+/[^\s]+)",
    Path(args.log).read_text(),
)
if not endpoints:
    raise SystemExit("No local Flutter VM service found in the supplied log")
endpoint = endpoints[-1].rstrip("/") + "/"
client = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def rpc(method, **parameters):
    url = endpoint + method + "?" + urllib.parse.urlencode(parameters)
    with client.open(url, timeout=15) as response:
        message = json.load(response)
    if "error" in message:
        raise RuntimeError(message["error"]["message"])
    return message["result"]


isolates = rpc("getVM")["isolates"]
isolate = isolates[args.isolate]["id"]
if not args.inspector:
    views = rpc("_flutter.listViews")["views"]
    view = next(item for item in views if item.get("isolate", {}).get("id") == isolate)
    result = rpc("_flutter.screenshot", viewId=view["id"])["screenshot"]
    Path(args.output).write_bytes(base64.b64decode(result))
    print(f"Captured rendered view {args.isolate} to {args.output}")
    raise SystemExit(0)
root = rpc(
    "ext.flutter.inspector.getRootWidgetSummaryTree",
    isolateId=isolate,
    objectGroup="rustdesk-validation",
)["result"]
result = rpc(
    "ext.flutter.inspector.screenshot",
    isolateId=isolate,
    id=root["valueId"],
    width=2400,
    height=1600,
    maxPixelRatio=1,
)["result"]
if not result:
    raise RuntimeError("Flutter view did not return a screenshot")
Path(args.output).write_bytes(base64.b64decode(result))
rpc("ext.flutter.inspector.disposeGroup", isolateId=isolate, objectGroup="rustdesk-validation")
print(f"Captured isolate {args.isolate} of {len(isolates)} to {args.output}")
