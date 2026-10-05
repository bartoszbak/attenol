#!/bin/sh
set -e
cd "$(dirname "$0")"
unsigned="$(mktemp -d)/Attenol Focus.shortcut"
plutil -convert binary1 -o "$unsigned" "Attenol Focus.plist"
shortcuts sign --mode anyone --input "$unsigned" --output "../Attenol/Attenol Focus.shortcut"
