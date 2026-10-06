#!/usr/bin/env bash
# Fetch every donor at its pin into $1 (default ./donors-src). Shallow, big blobs skipped at fetch. Run on the VPS, not the Mac.
set -euo pipefail
D=${1:-donors-src}; mkdir -p "$D"; cd "$D"
pin() { rm -rf "$1"; mkdir "$1"; (cd "$1" && git init -q && git remote add origin "$2" && git fetch -q --depth 1 --filter=blob:limit=2m origin "$3" && git -c advice.detachedHead=false checkout -q FETCH_HEAD && echo "$1 $(git rev-parse HEAD)"); }
pin world-of-claudecraft https://github.com/levy-street/world-of-claudecraft f46f30f5849989e44d7aa1bf62b3b14e435bc2fe
pin ModernUO https://github.com/modernuo/ModernUO 261ea01ab4b7c49a043dfabc7f44703b648883f8
pin EQEmu https://github.com/EQEmu/EQEmu 4aceae18b94ffaafc08e2b17bc41cd72c77f795d
pin openmw https://github.com/OpenMW/openmw 71fc0a4a2904ed9c315050194f51857ed598a8d1
pin OpenGothic https://github.com/Try/OpenGothic 801f6ed5da1d29c316e1b2d18d3e001a84b9ebf1
pin ZenKit https://github.com/GothicKit/ZenKit ddf27decd5eeb48ec715e6e66e5f5072c51d88ee
pin inkjs https://github.com/y-lohse/inkjs 6b1153410ab1c4bcfd9ef04eb2f0107f36be7778
