#!/bin/bash
# Checks a file (or a sha256 hash) against VirusTotal and prints the detection ratio.
#
# The API key is read from the macOS login keychain and is never stored in the repo.
# Store it once with:
#   security add-generic-password -a "$USER" -s virustotal-api-key -w "YOUR_KEY" -U
#
# Usage:
#   scripts/vt-check.sh <sha256-hash>
#   scripts/vt-check.sh path/to/Mac-Harmonium.dmg
set -euo pipefail

ARG="${1:?usage: vt-check.sh <sha256|file>}"

if [ -f "$ARG" ]; then
  HASH="$(shasum -a 256 "$ARG" | awk '{print $1}')"
else
  HASH="$ARG"
fi

KEY="$(security find-generic-password -s virustotal-api-key -w 2>/dev/null || true)"
if [ -z "$KEY" ]; then
  echo "No VirusTotal API key in the keychain (service 'virustotal-api-key')." >&2
  echo "Add it with: security add-generic-password -a \"\$USER\" -s virustotal-api-key -w \"YOUR_KEY\" -U" >&2
  exit 1
fi

RESP="$(curl -sS -H "x-apikey: $KEY" "https://www.virustotal.com/api/v3/files/$HASH")"

echo "$RESP" | /usr/bin/python3 -c '
import sys, json
d = json.load(sys.stdin)
if "error" in d:
    print("VirusTotal:", d["error"].get("message", d["error"]))
    sys.exit(1)
s = d["data"]["attributes"]["last_analysis_stats"]
mal = s.get("malicious", 0)
susp = s.get("suspicious", 0)
undet = s.get("undetected", 0)
harm = s.get("harmless", 0)
ran = mal + susp + undet + harm
print(f"{mal}/{ran} flagged malicious  (suspicious={susp}, undetected={undet})")
print("sha256:", d["data"]["id"])
'
