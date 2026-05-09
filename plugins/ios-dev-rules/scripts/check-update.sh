#!/bin/bash
# check-update.sh — 向后兼容 wrapper，调用 check-and-upgrade.sh --mode=check
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/check-and-upgrade.sh" --mode=check "$@"
