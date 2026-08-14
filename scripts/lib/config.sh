#!/usr/bin/env bash
# scripts/lib/config.sh
# Reads machine-local configuration. See doc/CONTRIBUTE.md for the
# rule that this file holds paths and counts only, never credentials.

# Read one key from a TOML table into stdout.
# Exits 0 always; absent keys produce empty output.
_cfg_get() {
    local file="$1" table="$2" key="$3"
    awk -v table="[${table}]" -v key="${key}" '
        $0 == table { in_table = 1; next }
        /^\[/ { in_table = 0 }
        in_table && $1 == key {
            sub(/^[^=]*=[[:space:]]*/, "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' "${file}"
}

# Resolve a path against the repository root when relative.
# Absolute paths pass through unchanged.
_cfg_abs() {
    local path="$1"
    [[ -z "${path}" ]] && return 0
    [[ "${path}" == /* ]] && {
        printf '%s' "${path}"
        return 0
    }
    printf '%s/%s' "$(git rev-parse --show-toplevel)" "${path}"
}

# Load configuration into CFG_* variables.
# Exits non-zero with a message naming what was not found.
load_config() {
    local file="$1"
    local key value missing=()

    if [[ ! -f "${file}" ]]; then
        echo "config file not found: ${file}" >&2
        return 1
    fi

    export CFG_FULL_DIR CFG_WEB_DIR CFG_EXPECTED_COUNT
    export CFG_MANIFEST_DIR CFG_COLLECTION_NAME

    CFG_FULL_DIR="$(_cfg_abs "$(_cfg_get "${file}" source full_dir)")"
    CFG_WEB_DIR="$(_cfg_abs "$(_cfg_get "${file}" source web_dir)")"
    CFG_EXPECTED_COUNT="$(_cfg_get "${file}" source expected_count)"
    CFG_MANIFEST_DIR="$(_cfg_abs "$(_cfg_get "${file}" output manifest_dir)")"
    CFG_COLLECTION_NAME="$(_cfg_get "${file}" output collection_name)"

    for key in full_dir web_dir expected_count \
        manifest_dir collection_name; do
        value="CFG_${key^^}"
        [[ -z "${!value}" ]] && missing+=("${key}")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "config ${file} missing keys: ${missing[*]}" >&2
        return 1
    fi

    for key in CFG_FULL_DIR CFG_WEB_DIR; do
        [[ -d "${!key}" ]] && continue
        echo "source directory not found: ${!key}" >&2
        return 1
    done
}
