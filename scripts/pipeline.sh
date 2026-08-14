#!/usr/bin/env bash
# Runs the normpic stages and verifies their output.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "${REPO_ROOT}/scripts/lib/config.sh"
source "${REPO_ROOT}/scripts/lib/stage.sh"
source "${REPO_ROOT}/scripts/lib/verify.sh"

load_config "${REPO_ROOT}/config.toml"

STAGE_RUN_DIR="${REPO_ROOT}/runs/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${STAGE_RUN_DIR}"
export STAGE_RUN_DIR

SCHEMA="$(normpic_schema_path)"

run_stage normpic-full -- normpic \
    --source-dir "${CFG_FULL_DIR}" \
    --dest-dir "${CFG_MANIFEST_DIR}/full" \
    --collection-name "${CFG_COLLECTION_NAME}"

run_stage normpic-web -- normpic \
    --source-dir "${CFG_WEB_DIR}" \
    --dest-dir "${CFG_MANIFEST_DIR}/web" \
    --collection-name "${CFG_COLLECTION_NAME}"

run_stage verify-full -- verify_collection \
    "${CFG_MANIFEST_DIR}/full" "${SCHEMA}" "${CFG_EXPECTED_COUNT}"

run_stage verify-web -- verify_collection \
    "${CFG_MANIFEST_DIR}/web" "${SCHEMA}" "${CFG_EXPECTED_COUNT}"

run_stage verify-pairing -- verify_pairing \
    "${CFG_MANIFEST_DIR}/full" "${CFG_MANIFEST_DIR}/web"

if grep -l failure "${STAGE_RUN_DIR}"/*.status >/dev/null 2>&1; then
    echo "pipeline: one or more stages failed" >&2
    echo "see ${STAGE_RUN_DIR}" >&2
    exit 1
fi

echo "pipeline: all stages succeeded"

