#!/usr/bin/env bash
# Runs normpic, galleria, verification, and upload as one pipeline.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
source "${REPO_ROOT}/scripts/lib/config.sh"
source "${REPO_ROOT}/scripts/lib/stage.sh"
source "${REPO_ROOT}/scripts/lib/verify.sh"
source "${REPO_ROOT}/scripts/lib/upload.sh"

CONFIG_DEFAULT="${XDG_CONFIG_HOME:-${HOME}/.config}/marcustack/config.toml"
load_config "${MARCUSTACK_CONFIG:-${CONFIG_DEFAULT}}"

STAGE_RUN_DIR="${REPO_ROOT}/runs/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${STAGE_RUN_DIR}"
export STAGE_RUN_DIR

# Exit 1 naming the run dir if any stage so far failed.
halt_on_failure() {
    if grep -l failure "${STAGE_RUN_DIR}"/*.status >/dev/null 2>&1; then
        echo "pipeline: a stage failed; see ${STAGE_RUN_DIR}" >&2
        exit 1
    fi
}

PICS="${CFG_SITE_DIR}/pics/${CFG_COLLECTION_NAME}"
SCHEMA="$(normpic_schema_path)"

run_stage normpic-original -- normpic \
    --source-dir "${CFG_FULL_DIR}" \
    --dest-dir "${PICS}/original" \
    --collection-name "${CFG_COLLECTION_NAME}"
run_stage normpic-display -- normpic \
    --source-dir "${CFG_WEB_DIR}" \
    --dest-dir "${PICS}/display" \
    --collection-name "${CFG_COLLECTION_NAME}"
run_stage verify-original -- verify_collection \
    "${PICS}/original" "${SCHEMA}" "${CFG_EXPECTED_COUNT}"
run_stage verify-display -- verify_collection \
    "${PICS}/display" "${SCHEMA}" "${CFG_EXPECTED_COUNT}"
run_stage verify-pairing -- verify_pairing \
    "${PICS}/original" "${PICS}/display"
halt_on_failure

run_stage galleria -- uv tool run \
    --from "git+https://github.com/marcus-grant/galleria@${CFG_GALLERIA_VERSION}" \
    python -m galleria build \
    --original-manifest "${PICS}/original/manifest.json" \
    --display-manifest "${PICS}/display/manifest.json" \
    --output-dir "${CFG_SITE_DIR}" \
    "${MARCUSTACK_DERIVE:---no-derive}"
run_stage verify-site -- verify_site \
    "${CFG_SITE_DIR}" "${CFG_COLLECTION_NAME}" "${CFG_EXPECTED_COUNT}"
halt_on_failure

[[ "${MARCUSTACK_UPLOAD:-0}" == "1" ]] || exit 0
run_stage upload -- upload_site \
    "${CFG_PICS_HDR}" "${CFG_SITE_HDR}" "${CFG_STORAGE_HOST}" \
    "${CFG_PICS_ZONE}" "${CFG_SITE_ZONE}" \
    "${CFG_SITE_DIR}" "${CFG_COLLECTION_NAME}"
halt_on_failure

echo "pipeline: all stages succeeded"
