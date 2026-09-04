#!/bin/bash
# Render generated panel HTML to submission-sized PNGs.
# Chrome's window size IS the output size, so no scaling step is needed.
#   ./render.sh OUTDIR WIDTH HEIGHT
set -e
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUTDIR="$1"; W="${2:-1320}"; H="${3:-2868}"
cd "$OUTDIR"
for html in *.html; do
  png="${html%.html}.png"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
            --force-device-scale-factor=1 --window-size="$W,$H" \
            --virtual-time-budget=3000 \
            --screenshot="$png" "file://$OUTDIR/$html" >/dev/null 2>&1
  printf '%s: %s\n' "$png" "$(sips -g pixelWidth -g pixelHeight "$png" | tail -2 | tr -d '\n' | tr -s ' ')"
done
