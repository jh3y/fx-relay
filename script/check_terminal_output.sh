#!/bin/bash
# Isolated native-to-terminal receipt check. Never uses an existing agent session.
set -euo pipefail
cd "$(dirname "$0")/.."
./script/build_and_run.sh --build-only
case_dir="$(python3 script/prepare_terminal_check.py)"
/usr/bin/open -n 'dist/FX Relay.app' --args --terminal-delivery-check "$case_dir"
for ((attempt=0; attempt<50; attempt++)); do
  if [[ -f "$case_dir/sender.json" ]]; then break; fi
  sleep 1
done
if [[ ! -f "$case_dir/sender.json" ]]; then
  echo "Check timed out. Quit FX Relay to release any test key, then reopen it normally. Reports: $case_dir" >&2
  exit 1
fi
# Let the receiver finish and the diagnostic process exit before normal startup.
sleep 1
/usr/bin/open 'dist/FX Relay.app'
python3 - "$case_dir" <<'PY'
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
sender = json.loads((root / 'sender.json').read_text())
print('Reports:', root)
if sender['status'] != 'completed':
    raise SystemExit(sender.get('error', 'Check stopped'))
receiver = json.loads((root / 'receiver.json').read_text())
for phase in sender['phases']:
    name = phase['mode']
    count = receiver['phases'].get(name, {}).get('spacesReceived', 0)
    expected = phase['downsPosted'] + phase['repeatsPosted']
    print(f'{name}: {count}/{expected} Spaces received')
    if name == 'direct-pid' and count != expected:
        raise SystemExit('Current delivery did not pass the terminal check')
PY
