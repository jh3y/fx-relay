#!/usr/bin/env python3
"""Prepare an isolated terminal receipt check; does not launch or send keys."""
import json
from pathlib import Path
import shlex
import uuid

root = Path(__file__).resolve().parent.parent
token = str(uuid.uuid4())
directory = root / "diagnostics" / ("terminal-delivery-" + token)
directory.mkdir(parents=True)
(directory / "request.json").write_text(json.dumps({"token": token}))
command = directory / "Receiver.command"
command.write_text("#!/bin/sh\nexec /usr/bin/python3 " + shlex.quote(str(root / "script/terminal_receiver.py")) + " " + shlex.quote(str(directory)) + "\n")
command.chmod(0o700)
print(directory)
