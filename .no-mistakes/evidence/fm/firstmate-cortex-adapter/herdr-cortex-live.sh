#!/usr/bin/env bash
set -u
ROOT=$1; EV=$2
LAB_HELPER=$ROOT/bin/fm-herdr-lab.sh
ORIGINAL_PATH=$PATH
SESSION=$("$LAB_HELPER" name herdr-cortex-live)
TMP=$(mktemp -d)
cleanup(){ PATH="$ORIGINAL_PATH" "$LAB_HELPER" teardown "$SESSION"; rm -rf "$TMP"; }
trap cleanup EXIT
mkdir -p "$TMP/fakebin" "$TMP/proj"
cat > "$TMP/fakebin/herdr" <<EOF
#!/usr/bin/env bash
args=("\$@"); n=\${#args[@]}
if [ "\$n" -ge 2 ] && [ "\${args[\$((n-2))]}" = --session ]; then args=("\${args[@]:0:\$((n-2))}"); else exit 98; fi
exec env PATH="$ORIGINAL_PATH" "$LAB_HELPER" run "$SESSION" "\${args[@]}"
EOF
chmod +x "$TMP/fakebin/herdr"
"$LAB_HELPER" provision "$SESSION" || exit 1
export PATH="$TMP/fakebin:$ORIGINAL_PATH"
. "$ROOT/bin/backends/herdr.sh"
lab(){ env PATH="$ORIGINAL_PATH" "$LAB_HELPER" run "$SESSION" "$@"; }
WS=$(lab workspace create --cwd "$TMP/proj" --label fm-cxlive --no-focus)
PANE=$(printf '%s' "$WS" | jq -er '.result.root_pane.pane_id')
TARGET="$SESSION:$PANE"
lab pane run "$PANE" "cortex --dangerously-allow-all-tool-calls -- 'Reply with the single word OK and nothing else.'" >/dev/null
sleep 25
lab pane report-agent "$PANE" --source firstmate:cortex --agent cortex --state idle >/dev/null 2>&1; lab pane read "$PANE" --source visible | tail -5
for i in $(seq 1 60); do
  sleep 1
  s=$(lab pane read "$PANE" --source visible 2>/dev/null)
    v=$(fm_backend_herdr_composer_state "$TARGET"); echo "t=$i $v"; [ "$v" = empty ] && break
done
echo "agent get:"; lab agent get "$PANE" | jq -c '.result.agent'
echo "composer idle verdict: $(fm_backend_herdr_composer_state "$TARGET")"
lab pane read "$PANE" --source visible | tail -15 > "$EV/herdr-cortex-idle-screen.txt"
lab pane send-text "$PANE" "draft text here" >/dev/null 2>&1 || lab pane send-keys "$PANE" d r a f t >/dev/null
sleep 1
echo "composer with draft verdict: $(fm_backend_herdr_composer_state "$TARGET")"
lab pane read "$PANE" --source visible | tail -15 > "$EV/herdr-cortex-draft-screen.txt"
