#!/usr/bin/env bash
# Driver: real cortex on a real Herdr lab pane, via real fm-spawn --relaunch.
set -u
ROOT=$(pwd)
. "$ROOT/tests/lib.sh"
. "$ROOT/tests/herdr-test-safety.sh"
herdr_forget_inherited_pane
SESSION="fm-lab-cortex-$$"
export HERDR_SESSION="$SESSION"
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/fm-cortex-herdr.XXXXXX"); SCRATCH=$(cd "$SCRATCH" && pwd -P)
LAB=0
cleanup() {
  chmod -R u+w "$SCRATCH" 2>/dev/null
  rm -rf "$SCRATCH"
  [ "$LAB" = 1 ] && herdr_safe_stop_and_delete "$SESSION"
}
trap cleanup EXIT
fail() { echo "NOT OK: $*"; exit 1; }
fm_herdr_lab_prepare "$SESSION" || fail prepare
LAB=1
H="$SCRATCH/home"; mkdir -p "$H/state" "$H/data/ct" "$H/config"
cat > "$H/data/ct/brief.md" <<'B'
# Task
## Captain's intent
Reply with the single word READY and then stop. Do not run any tool.

## Firstmate spec
Reply READY.
B
PROJ="$SCRATCH/proj"; WT="$SCRATCH/wt"
mkdir -p "$PROJ"; git -C "$PROJ" init -q; echo x > "$PROJ/README.md"; git -C "$PROJ" add .
git -C "$PROJ" -c user.name=t -c user.email=t@example.invalid commit -qm init
git -C "$PROJ" worktree add -q -b ct "$WT"
. "$ROOT/bin/fm-backend.sh"; fm_backend_source herdr || fail source
CR=$(fm_backend_herdr_container_ensure "$WT") || fail container
CONTAINER=${CR%%$'\t'*}; SEED=${CR#*$'\t'}; WS=${CONTAINER#*:}
read -r TAB PANE <<<"$(fm_backend_herdr_create_task "$CONTAINER" fm-ct "$WT" "$SEED")"
{ echo "window=$SESSION:$PANE"; echo endpoint_task_id=ct; echo "worktree=$WT"; echo "project=$PROJ"
  echo harness=claude; echo kind=ship; echo mode=no-mistakes; echo yolo=off; echo model=default; echo effort=default
  echo backend=herdr; echo "herdr_session=$SESSION"; echo "herdr_workspace_id=$WS"; echo "herdr_tab_id=$TAB"; echo "herdr_pane_id=$PANE"; } > "$H/state/ct.meta"
OUT=$(env FM_HOME="$H" HERDR_SESSION="$SESSION" FM_SPAWN_NO_GUARD=1 "$ROOT/bin/fm-spawn.sh" ct --relaunch --harness cortex 2>&1) || fail "relaunch: $OUT"
echo "relaunch: $OUT"
EP="$SESSION:$PANE"
for i in $(seq 1 60); do
  S=$(fm_backend_agent_state herdr "$EP"); [ "$S" = alive ] && break; sleep 1
done
echo "agent_state=$S after ${i}s"
sleep 8
echo "--- screen ---"
herdr pane read "$PANE" --session "$SESSION" 2>&1 | tail -25
echo "--- herdr agent get ---"
herdr agent get "$PANE" --session "$SESSION" 2>&1 | head -20
C=$(fm_backend_composer_state herdr "$EP" 2>&1); echo "composer_state=$C"
OUT=$(env FM_HOME="$H" HERDR_SESSION="$SESSION" FM_SPAWN_NO_GUARD=1 FM_CONTROL_POLL=0.2 FM_CONTROL_EXIT_WAIT=5 "$ROOT/bin/fm-control.sh" ct exit 2>&1); echo "exit: $OUT"
sleep 2
echo "agent_state_after_exit=$(fm_backend_agent_state herdr "$EP")"
