#!/usr/bin/env bash
# (C) Crown Copyright 2026, Met Office.
# The LICENSE.md file contains full licensing details.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

ESMVALTOOL_MODULE_NAME="${ESMVALTOOL_MODULE_NAME:-scitools/community/esmvaltool/2.13.0}"

if ! command -v pytest >/dev/null 2>&1; then
	if command -v module >/dev/null 2>&1; then
		echo "Loading module ${ESMVALTOOL_MODULE_NAME} to access pytest..."
		module load "${ESMVALTOOL_MODULE_NAME}"
	fi
fi

if command -v pytest >/dev/null 2>&1; then
	PYTEST_CMD=(pytest)
elif command -v cmew-esmvaltool-env >/dev/null 2>&1; then
	PYTEST_CMD=(cmew-esmvaltool-env pytest)
else
	echo "Error: could not find 'pytest' or 'cmew-esmvaltool-env' on PATH." >&2
	echo "Load ${ESMVALTOOL_MODULE_NAME} or activate the CMEW environment, then retry." >&2
	exit 1
fi

if ! command -v cylc >/dev/null 2>&1; then
	echo "Error: could not find 'cylc' on PATH." >&2
	echo "Activate the CMEW environment, then retry." >&2
	exit 1
fi

echo "Running unit tests with pytest..."
"${PYTEST_CMD[@]}" CMEW/app/unittest/tests

echo "Unit tests passed. Running CMEW workflow..."
cd CMEW

WORKFLOW_NAME="${CYLC_WORKFLOW_NAME:-CMEWexperimental}"

echo "Starting cut-down development workflow for ${WORKFLOW_NAME}..."
cylc vip -O dev -n "${WORKFLOW_NAME}"

echo "Development workflow submitted successfully."
echo "Run full pre-PR validation separately with: cylc vip -n ${WORKFLOW_NAME} -O metoffice -O test"
