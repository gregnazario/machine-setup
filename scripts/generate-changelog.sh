#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT="${1:-${REPO_DIR}/CHANGELOG.md}"
SINCE="${2:-}"

generate_changelog() {
    local since_arg=""
    if [[ -n "$SINCE" ]]; then
        since_arg="$SINCE..HEAD"
    fi

    local feats="" fixes="" refactors="" docs="" ci="" perfs="" security="" other=""

    while IFS= read -r line; do
        local hash="${line%% *}"
        local msg="${line#* }"
        local short_hash="${hash:0:7}"
        local entry="- ${msg} (\`${short_hash}\`)"

        case "$msg" in
            feat:*|feat\(*) feats="${feats}${entry}\n" ;;
            fix:*|fix\(*) fixes="${fixes}${entry}\n" ;;
            refactor:*|refactor\(*) refactors="${refactors}${entry}\n" ;;
            docs:*|docs\(*) docs="${docs}${entry}\n" ;;
            ci:*|ci\(*) ci="${ci}${entry}\n" ;;
            perf:*|perf\(*) perfs="${perfs}${entry}\n" ;;
            security:*|security\(*) security="${security}${entry}\n" ;;
            *) other="${other}${entry}\n" ;;
        esac
    done < <(git -C "$REPO_DIR" log --oneline --no-merges $since_arg 2>/dev/null)

    {
        echo "# Changelog"
        echo ""
        echo "All notable changes to this project are documented in this file."
        echo ""
        echo "Generated from conventional commits on $(date +%Y-%m-%d)."
        echo ""

        if [[ -n "$feats" ]]; then
            echo "## Features"
            echo ""
            echo -e "$feats"
        fi

        if [[ -n "$fixes" ]]; then
            echo "## Bug Fixes"
            echo ""
            echo -e "$fixes"
        fi

        if [[ -n "$security" ]]; then
            echo "## Security"
            echo ""
            echo -e "$security"
        fi

        if [[ -n "$perfs" ]]; then
            echo "## Performance"
            echo ""
            echo -e "$perfs"
        fi

        if [[ -n "$refactors" ]]; then
            echo "## Refactoring"
            echo ""
            echo -e "$refactors"
        fi

        if [[ -n "$docs" ]]; then
            echo "## Documentation"
            echo ""
            echo -e "$docs"
        fi

        if [[ -n "$ci" ]]; then
            echo "## CI/CD"
            echo ""
            echo -e "$ci"
        fi

        if [[ -n "$other" ]]; then
            echo "## Other"
            echo ""
            echo -e "$other"
        fi
    } > "$OUTPUT"

    log_success "Changelog generated: $OUTPUT"
    local count
    count=$(grep -c "^- " "$OUTPUT")
    log_info "Total entries: $count"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_changelog
fi
