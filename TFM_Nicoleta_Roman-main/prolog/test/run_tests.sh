#!/usr/bin/env bash
#
# Automated test runner for the ODRL Policy Authorizer.
#
# Runs, in order:
#   1. Unit tests            (test/unit_tests.plt)
#   2. Integration/regression (test/integration_tests.plt)
#   3. System test            (end-to-end HTTP against a live server.pl)
#
# Exit code is non-zero if any stage fails, so it can be used in CI.
#
# Usage:  ./test/run_tests.sh

set -euo pipefail

# Resolve the prolog/ directory (parent of this script) and run from there.
PROLOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROLOG_DIR"

echo "==================================================================="
echo " Unit + Integration + Regression tests (plunit)"
echo "==================================================================="
swipl -q -g "consult('test/unit_tests.plt'), \
             consult('test/integration_tests.plt'), \
             ( run_tests -> halt(0) ; halt(1) )"

echo
echo "==================================================================="
echo " System test (end-to-end HTTP API)"
echo "==================================================================="

# Start the server in the background and make sure it is stopped on exit.
swipl -q server.pl </dev/null >/tmp/odrl_server.log 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Give the HTTP server a moment to bind the port; the client also retries.
sleep 1

swipl -q -g "consult('test/system_tests.pl'), ( system_test -> halt(0) ; halt(1) )"

echo
echo "All test stages passed."