#!/usr/bin/env bash
# shout.sh [--times N] <text> — prints <text> in upper case, N times (default 1).
times=1
if [ "${1:-}" = "--times" ]; then times="${2:?--times needs a number}"; shift; fi
text="${1:?usage: shout.sh [--times N] <text>}"
for i in $(seq 1 $times); do
    echo "$text" | tr '[:lower:]' '[:upper:]'
done
