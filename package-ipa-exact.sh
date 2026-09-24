#!/bin/bash
set -euo pipefail

APP="${1:-build/Build/Products/Release-iphoneos/WeatherShare.app}"
OUT="${2:-WeatherShare-unsigned.ipa}"

test -d "$APP"
test -f "$APP/WeatherShare"

rm -rf Payload
mkdir -p Payload
cp -R "$APP" Payload/WeatherShare.app

rm -f "$OUT"
ditto -c -k --sequesterRsrc --keepParent Payload "$OUT"

echo "Created: $OUT"
echo "Expected internal layout:"
unzip -l "$OUT" | sed -n '1,35p'
