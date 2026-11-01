#!/usr/bin/env bash
name="${1:-}"
if [ -z "$name" ]; then echo "usage: farewell.sh <name>" >&2; exit 0; fi
echo "Goodbye, $name."
