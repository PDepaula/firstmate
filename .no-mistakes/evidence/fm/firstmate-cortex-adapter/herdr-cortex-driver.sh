#!/usr/bin/env bash
# Live Herdr lab: real cortex in a lab pane; adapter composer_state with/without Cortex registration.
set -u
ROOT=$1; LAB_HELPER=$ROOT/bin/fm-herdr-lab.sh
ORIGINAL_PATH=$PATH
SESSION=$("$LAB_HELPER" name cortexlive)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-cxh.XXXXXX"); FAKEBIN=$TMP/fakebin; mkdir -p "$FAKEBIN" "$TMP/proj"
cleanup() { PATH="$ORIGINAL_PATH" "$LAB_HELPER" teardown "$SESSION"; rm -rf "$TMP"; }
trap cleanup EXIT
cat > "$FAKEBIN/herdr" <<EOT
#!/usr/bin/env bash
args=("\$@"); n=\${#args[@]}
if [ "\$n" -ge 2 ] && [ "\${args[\$((n-2))]}" = --session ]; then
  [ "\${args[\$((n-1))]}" = "$SESSION" ] || exit 97
  args=("\${args[@]:0:\$((n-2))}")
else exit 98; fi
exec env PATH="$ORIGINAL_PATH" "$LAB_HELPER" run "$SESSION" "\${args[@]}"
EOT
chmod +x "$FAKEBIN/herdr"
"$LAB_HELPER" provision "$SESSION" || { echo provision-failed; exit 1; }
export PATH="$FAKEBIN:$ORIGINAL_PATH"
. "$ROOT/bin/backends/herdr.sh"
lab() { env PATH="$ORIGINAL_PATH" "$LAB_HELPER" run "$SESSION" "$@"; }
PANE=$(lab workspace create --cwd "$TMP/proj" --label cxlive --no-focus | jq -er '.result.root_pane.pane_id')
TARGET="$SESSION:$PANE"
lab pane run "$PANE" "cortex --dangerously-allow-all-tool-calls" >/dev/null
for i in $(seq 40); do lab pane read "$PANE" --source visible 2>/dev/null | grep -q 'Type your message' && break; sleep 1; done
lab pane read "$PANE" --source visible > "$TMP/screen.txt"; grep -v '^\s*$' "$TMP/screen.txt" | tail -6
echo "agent before report: $(lab agent get "$PANE" | jq -c '.result.agent|{agent,agent_status}')"
echo "UNREGISTERED idle composer: $(fm_backend_herdr_composer_state "$TARGET")"
lab pane report "$PANE" --source firstmate:cortex --agent cortex --state idle >/dev/null 2>&1 || lab pane report --help 2>&1 | head -20
echo "agent after report: $(lab agent get "$PANE" | jq -c '.result.agent|{agent,agent_status}')"
echo "REGISTERED idle composer: $(fm_backend_herdr_composer_state "$TARGET")"
lab pane send-text "$PANE" "draft not sent" >/dev/null 2>&1 || lab pane run "$PANE" "" >/dev/null
sleep 2
echo "REGISTERED with draft: $(fm_backend_herdr_composer_state "$TARGET")"
lab pane read "$PANE" --source visible | grep -v '^\s*$' | tail -5
