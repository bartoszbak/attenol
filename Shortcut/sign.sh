#!/bin/sh
# Rebuilds the signed shortcut the app bundles from its plist source. Needs a network
# connection: signing goes through Apple.
set -e
cd "$(dirname "$0")"
unsigned="$(mktemp -d)/Attenol Focus.shortcut"
plutil -convert binary1 -o "$unsigned" "Attenol Focus.plist"
shortcuts sign --mode anyone --input "$unsigned" --output "../Attenol/Attenol Focus.shortcut"
