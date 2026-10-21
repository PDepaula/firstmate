#!/usr/bin/env bash
# usage: classify.sh <worktree> <tmux-socket-name> <target>
ROOT=$1; SOCK=$2; T=$3
REAL=$(command -v tmux)
tmux() { "$REAL" -L "$SOCK" "$@"; }
export -f tmux 2>/dev/null
. "$ROOT/bin/fm-tmux-lib.sh"
fm_tmux_composer_state "$T"; echo
