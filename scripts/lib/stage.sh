#!/usr/bin/env bash
# scripts/lib/stage.sh
# The marcustack spine. See doc/v01.md "Stage contract" for the design.
# Implements spec 1 only; next increment is PR-001 in doc/TODO.md.

run_stage() {
    local name="$1"
    shift
    [[ "${1:-}" == "--" ]] && shift
    if "$@"; then
        echo "success" > "${STAGE_RUN_DIR}/${name}.status"
    fi
}