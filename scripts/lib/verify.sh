#!/usr/bin/env bash
# Verification helpers for pipeline output.

# Print the path to normpic's shipped schema.
# Exits non-zero if the installed package cannot be located.
normpic_schema_path() {
    local found
    found="$(find "${HOME}/.local/share/uv/tools/normpic" \
        -name 'v0.1.0.json' -path '*normpic/schema*' 2>/dev/null | head -1)"
    if [[ -z "${found}" ]]; then
        echo "normpic schema not found; is normpic installed?" >&2
        return 1
    fi
    printf '%s' "${found}"
}

# Verify one collection: schema, symlinks, and entry count.
# Exits non-zero naming the first failure.
verify_collection() {
    local dir="$1" schema="$2" expected="$3"
    local manifest="${dir}/manifest.json" actual broken

    if [[ ! -f "${manifest}" ]]; then
        echo "manifest not found: ${manifest}" >&2
        return 1
    fi

    if ! check-jsonschema --schemafile "${schema}" "${manifest}"; then
        echo "manifest failed schema validation: ${manifest}" >&2
        return 1
    fi

    broken="$(find "${dir}" -xtype l | wc -l)"
    if [[ "${broken}" -ne 0 ]]; then
        echo "broken symlinks in ${dir}: ${broken}" >&2
        return 1
    fi

    actual="$(jq '.pic | length' "${manifest}")"
    if [[ "${actual}" -ne "${expected}" ]]; then
        echo "entry count mismatch in ${manifest}" >&2
        echo "actual ${actual}, expected ${expected}" >&2
        return 1
    fi
}

# Verify both collections pair on relative_path.
# Exits non-zero reporting how many entries failed to pair.
verify_pairing() {
    local full="$1/manifest.json" web="$2/manifest.json"
    local unpaired

    unpaired="$(diff \
        <(jq -r '.pic[].relative_path' "${full}" | sort) \
        <(jq -r '.pic[].relative_path' "${web}" | sort) | grep -c '^[<>]' \
        || true)"

    if [[ "${unpaired}" -ne 0 ]]; then
        echo "collections do not pair: ${unpaired} unpaired entries" >&2
        return 1
    fi
}