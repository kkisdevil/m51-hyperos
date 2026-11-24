#!/usr/bin/env bash
# run_mock_e2e.sh — end-to-end test of mercury-rename without a real key.
#
# Proves, against a local mock Mercury server:
#   1. rename.py renames the unnamed function and skips the already-named
#      one and the failed decompilation.
#   2. A second run over the same dump makes ZERO new API calls (cache).
#   3. apply_names.py writes renamed C containing the new name.
#   4. --dry-run makes zero API calls and writes nothing.
#
# Usage: bash tests/run_mock_e2e.sh   (run from tools/mercury-rename/)

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${TOOL_DIR}"

PORT="${MOCK_PORT:-8931}"
BASE_URL="http://127.0.0.1:${PORT}/v1"
# The mock ignores Authorization, but the client still requires *some*
# key value (it fails loudly without one) — supply a placeholder.
export MERCURY_API_KEY="mock-test-key"
WORK="$(mktemp -d)"
COUNT_FILE="${WORK}/calls.txt"
: > "${COUNT_FILE}"
MOCK_LOG="${WORK}/mock.log"

fail() { echo "E2E FAIL: $*" >&2; exit 1; }
check() { "$@" || fail "$*"; }
calls() { wc -l < "${COUNT_FILE}" | tr -d " "; }

echo "e2e: starting mock Mercury on :${PORT}"
MOCK_COUNT_FILE="${COUNT_FILE}" python3 tests/mock_mercury.py "${PORT}" \
    > "${MOCK_LOG}" 2>&1 &
MOCK_PID=$!
trap 'kill ${MOCK_PID} 2>/dev/null || true; rm -rf "${WORK}"' EXIT
for _ in $(seq 1 50); do
    curl -sf "${BASE_URL}/models" >/dev/null 2>&1 && break
    sleep 0.2
done
curl -sf "${BASE_URL}/models" >/dev/null \
    || fail "mock server did not come up (see ${MOCK_LOG})"

echo "e2e: run 1 — rename against the mock"
check python3 rename.py tests/sample_dump.json \
    --out "${WORK}/renamed.json" --cache "${WORK}/cache.db" \
    --base-url "${BASE_URL}" --model mercury-3
check test "$(calls)" = "1"

echo "e2e: assert run-1 output"
python3 - "$WORK/renamed.json" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
by_addr = {r["address"]: r for r in data["renames"]}
assert len(data["renames"]) == 1, data["renames"]
r = by_addr["0x101000"]
assert r["old_name"] == "FUN_00101000", r
assert r["new_name"] == "renamed_fun_00101000", r
assert r["summary"] == "Mock rename of FUN_00101000", r
assert r["confidence"] == 0.95, r
assert r["cached"] is False, r
assert r["needs_review"] is False, r
assert data["stats"]["api_calls"] == 1, data["stats"]
print("e2e: run-1 assertions OK")
PYEOF

echo "e2e: run 2 — same dump, must be a pure cache hit"
check python3 rename.py tests/sample_dump.json \
    --out "${WORK}/renamed2.json" --cache "${WORK}/cache.db" \
    --base-url "${BASE_URL}" --model mercury-3
check test "$(calls)" = "1"
python3 - "$WORK/renamed2.json" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["renames"][0]["cached"] is True, data["renames"]
assert data["stats"]["api_calls"] == 0, data["stats"]
assert data["stats"]["cached"] == 1, data["stats"]
print("e2e: cache-hit assertions OK (zero new API calls)")
PYEOF

echo "e2e: dry-run — zero calls, nothing written"
check python3 rename.py tests/sample_dump.json \
    --out "${WORK}/dry.json" --cache "${WORK}/cache.db" \
    --base-url "${BASE_URL}" --model mercury-3 --dry-run
check test "$(calls)" = "1"
check test ! -e "${WORK}/dry.json"

echo "e2e: applier — renamed C + Ghidra script"
check python3 apply_names.py tests/sample_dump.json "${WORK}/renamed.json" \
    --out-c "${WORK}/libsample.renamed.c" \
    --out-script "${WORK}/ApplyNames.py"
grep -q "renamed_fun_00101000" "${WORK}/libsample.renamed.c" \
    || fail "renamed C lacks the new name"
grep -q "Mock rename of FUN_00101000" "${WORK}/libsample.renamed.c" \
    || fail "renamed C lacks the summary comment"
grep -q "FUN_00101000(" "${WORK}/libsample.renamed.c" \
    && fail "renamed C still calls/defines the old name"
grep -q "setName" "${WORK}/ApplyNames.py" \
    || fail "Ghidra script lacks setName"
grep -q "getScriptArgs" "${WORK}/ApplyNames.py" \
    || fail "Ghidra script does not read the renamed JSON path"
# The script itself holds no names — it reads them from renamed.json
# at run time (already asserted above to contain the new name).

echo "e2e: ALL CHECKS PASSED (mock calls total: $(calls))"
