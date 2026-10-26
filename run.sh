#!/usr/bin/env bash
# Play:            ./run.sh
# Autopilot demo:  ./run.sh --bot
# Short run:       ./run.sh --minutes=8
# Jump to a tier:  ./run.sh --start_r=30 --start_t=720
# Playtest + shots ./run.sh --bot --shots=/tmp/cm --shot_every=30 --quit_after=1260
cd "$(dirname "$0")"
GODOT="${GODOT:-.tools/godot}"
[ -x "$GODOT" ] || GODOT="$(command -v godot)"
extra=()
# headless-style playtests (with --shots) simulate as fast as the machine allows
for a in "$@"; do [[ "$a" == --shots=* ]] && extra=(--fixed-fps 60 --disable-vsync); done
exec "$GODOT" --path . "${extra[@]}" -- "$@"
