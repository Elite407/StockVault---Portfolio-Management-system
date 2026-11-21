#!/usr/bin/env bash
# ============================================================
# StockVault — Test Runner
# Runs all SQL test files in order and reports results.
#
# Usage:
#   ./tests/run_tests.sh
#
# Prerequisites:
#   - PostgreSQL is running with the stockvault database
#   - Schema, seed data, indexes, views, and triggers are loaded
#   - PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE are set
#     (or defaults: localhost, 5432, postgres, postgres, stockvault)
# ============================================================

set -euo pipefail

# ── Config ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
RESULTS=()

# Default connection params (override via env vars)
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-stockvault}"

# ── Test files in execution order ──────────────────────────────
TEST_FILES=(
    "test_schema.sql"
    "test_constraints.sql"
    "test_triggers.sql"
    "test_views.sql"
    "test_indexes.sql"
    "test_seed_data.sql"
    "test_rls.sql"
    "test_financial_invariants.sql"
    "test_queries.sql"
)

# ── Banner ─────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     StockVault — Database Test Suite                 ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Host: $PGHOST:$PGPORT                              "
echo "║  DB:   $PGDATABASE                                   "
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Run each test file ─────────────────────────────────────────
for test_file in "${TEST_FILES[@]}"; do
    filepath="${SCRIPT_DIR}/${test_file}"

    if [[ ! -f "$filepath" ]]; then
        echo "⚠️  SKIP: ${test_file} (file not found)"
        RESULTS+=("SKIP  ${test_file}")
        continue
    fi

    echo "── Running: ${test_file} ──────────────────────────────"

    if psql -v ON_ERROR_STOP=1 -f "$filepath" 2>&1; then
        echo "✅ PASS: ${test_file}"
        RESULTS+=("PASS  ${test_file}")
        PASS=$((PASS + 1))
    else
        echo "❌ FAIL: ${test_file}"
        RESULTS+=("FAIL  ${test_file}")
        FAIL=$((FAIL + 1))
    fi

    echo ""
done

# ── Summary ────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════╗"
echo "║                  TEST SUMMARY                        ║"
echo "╠══════════════════════════════════════════════════════╣"

for result in "${RESULTS[@]}"; do
    status="${result:0:4}"
    file="${result:6}"
    if [[ "$status" == "PASS" ]]; then
        echo "║  ✅ ${file}"
    elif [[ "$status" == "FAIL" ]]; then
        echo "║  ❌ ${file}"
    else
        echo "║  ⚠️  ${file}"
    fi
done

echo "╠══════════════════════════════════════════════════════╣"
echo "║  Total: $((PASS + FAIL))  |  Passed: ${PASS}  |  Failed: ${FAIL}          "
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Exit code ──────────────────────────────────────────────────
if [[ $FAIL -gt 0 ]]; then
    echo "💥 ${FAIL} test file(s) FAILED"
    exit 1
else
    echo "🎉 All tests passed!"
    exit 0
fi
