#!/bin/sh
# Alle Modelle neu erzeugen: ./blender/build_all.sh   (oder einzelne: ./blender/build_all.sh blaster shop)
cd "$(dirname "$0")"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
MODELS="${*:-$(ls *.py | grep -v common.py | sed 's/\.py$//')}"
for m in $MODELS; do
  "$BLENDER" -b --factory-startup -P "$m.py" 2>&1 | grep -E "\[aero\]|Error|Traceback|File \"" || exit 1
done
