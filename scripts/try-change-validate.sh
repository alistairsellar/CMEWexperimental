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

echo "Starting workflow ${WORKFLOW_NAME} and waiting for completion..."
set +e
cylc vip -N --abort-if-any-task-fails -n "${WORKFLOW_NAME}" -O metoffice -O test
VIP_EXIT_CODE=$?
set -e

RUN_LINK="${HOME}/cylc-run/${WORKFLOW_NAME}/runN"
if [[ ! -L "${RUN_LINK}" ]]; then
	echo "Error: could not find run symlink at ${RUN_LINK}." >&2
	exit 1
fi
WORKFLOW_RUN_NAME="$(basename "$(readlink "${RUN_LINK}")")"
WORKFLOW_ID="${WORKFLOW_NAME}/${WORKFLOW_RUN_NAME}"

echo "Checking final workflow state for ${WORKFLOW_ID}..."
WORKFLOW_STATE_OUTPUT="$(cylc workflow-state "${WORKFLOW_ID}" --max-polls=1 --pretty)"
echo "${WORKFLOW_STATE_OUTPUT}"

FAILED_TASKS="$(printf '%s\n' "${WORKFLOW_STATE_OUTPUT}" | grep -E ':(failed|submit-failed)$' || true)"
if [[ -n "${FAILED_TASKS}" ]]; then
	echo "Error: workflow completed with failed tasks:" >&2
	echo "${FAILED_TASKS}" >&2
	exit 1
fi

if [[ "${VIP_EXIT_CODE}" -ne 0 ]]; then
	echo "Error: cylc vip exited with status ${VIP_EXIT_CODE}." >&2
	exit "${VIP_EXIT_CODE}"
fi

echo "Workflow completed successfully with no failed tasks."
