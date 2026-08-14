#!/usr/bin/env bash
# scripts/lib/stage.sh
# The marcustack spine. See doc/v01.md "Stage contract" for the design.
# Implements spec 1 only; next increment is PR-001 in doc/TODO.md.

run_stage() {
    local name="$1"
    if [[ -z "${STAGE_RUN_DIR:-}" ]]; then
        echo "STAGE_RUN_DIR is not set" >&2
        return 1
    fi
    if [[ ! -d "${STAGE_RUN_DIR}" ]]; then
        echo "STAGE_RUN_DIR does not exist: ${STAGE_RUN_DIR}" >&2
        return 1
    fi
    shift
    [[ "${1:-}" == "--" ]] && shift
    if "$@"; then
        echo "success" >"${STAGE_RUN_DIR}/${name}.status"
    else
        echo "stage failed: ${name}" >&2
        echo "failure" >"${STAGE_RUN_DIR}/${name}.status"
    fi
    return 0
}
