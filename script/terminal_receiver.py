#!/usr/bin/env python3
"""Count Space bytes in this test terminal only. No audio or typed text is saved."""
import collections
import json
import os
from pathlib import Path
import select
import sys
import termios
import time
import tty

directory = Path(sys.argv[1])
request = json.loads((directory / "request.json").read_text())
token = request["token"]
print(f"\033]0;FX Relay Terminal Check {token}\007", end="", flush=True)
print("FX Relay terminal delivery check — leave this window focused for about 5 seconds.")
print("Only test Spaces are counted. Your Claude session is not used. The check finishes automatically.")
settings = termios.tcgetattr(sys.stdin)
phases = collections.defaultdict(lambda: {"spacesReceived": 0, "otherBytes": 0, "packets": []})
try:
    tty.setraw(sys.stdin.fileno())
    (directory / "ready.json").write_text(json.dumps({"pid": os.getpid(), "token": token}))
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        if (directory / "done.json").exists():
            break
        ready, _, _ = select.select([sys.stdin], [], [], .05)
        if not ready:
            continue
        data = os.read(sys.stdin.fileno(), 1024)
        try:
            phase = json.loads((directory / "phase.json").read_text())["phase"]
        except (OSError, ValueError, KeyError):
            phase = "waiting"
        record = phases[phase]
        record["spacesReceived"] += data.count(b" ")
        record["otherBytes"] += len(data) - data.count(b" ")
        record["packets"].append({"time": time.monotonic(), "spaces": data.count(b" "), "otherBytes": len(data) - data.count(b" ")})
        if b"\x03" in data:  # Physical Ctrl+C can stop the receiver; no contents retained.
            break
finally:
    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, settings)
    (directory / "receiver.json").write_text(json.dumps({"phases": dict(phases)}, indent=2) + "\n")
    print("\nCheck finished. Receipt counts saved locally.")
