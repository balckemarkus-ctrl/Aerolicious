#!/usr/bin/env bash
# Erzeugt trailer.mp4: Build -> Preview-Server -> Frames rendern -> Tonspur synthetisieren -> ffmpeg.
# Voraussetzungen: Node, Python 3, ffmpeg, Playwright mit Chromium.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=${OUT:-trailer-build}
npm run build
npx vite preview --port 4173 --strictPort > /dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER' EXIT
sleep 2
node tools/trailer/record.mjs "$OUT"
python3 tools/trailer/synth.py "$OUT/events.json" "$OUT/music.wav" 48
ffmpeg -y -framerate 30 -i "$OUT/frames/%05d.jpg" -i "$OUT/music.wav" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart trailer.mp4
echo "Fertig: trailer.mp4"
