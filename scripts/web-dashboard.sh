#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PORT="${1:-8080}"
SERVE_DIR="$(mktemp -d)"

generate_html() {
    local status_output
    status_output=$(bash "${REPO_DIR}/scripts/status-dashboard.sh" --profile "${PROFILE:-auto}" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')

    local health_output=""
    if [[ -x "${REPO_DIR}/scripts/check-health.sh" ]]; then
        health_output=$(bash "${REPO_DIR}/scripts/check-health.sh" --profile "${PROFILE:-auto}" 2>&1 | sed 's/\x1b\[[0-9;]*m//g') || true
    fi

    local conflict_output=""
    if [[ -x "${REPO_DIR}/scripts/detect-conflicts.sh" ]]; then
        conflict_output=$(bash "${REPO_DIR}/scripts/detect-conflicts.sh" --profile "${PROFILE:-auto}" 2>&1 | sed 's/\x1b\[[0-9;]*m//g') || true
    fi

    cat > "${SERVE_DIR}/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="30">
    <title>Machine Setup Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'SF Mono', 'Menlo', 'Consolas', monospace; background: #1a1b26; color: #a9b1d6; padding: 2rem; }
        h1 { color: #7aa2f7; margin-bottom: 1.5rem; font-size: 1.5rem; }
        h2 { color: #bb9af7; margin: 1.5rem 0 0.75rem; font-size: 1.1rem; }
        .card { background: #24283b; border-radius: 8px; padding: 1.25rem; margin-bottom: 1rem; border: 1px solid #414868; }
        pre { white-space: pre-wrap; word-wrap: break-word; font-size: 0.85rem; line-height: 1.6; }
        .success { color: #9ece6a; }
        .warn { color: #e0af68; }
        .error { color: #f7768e; }
        .info { color: #7dcfff; }
        .meta { color: #565f89; font-size: 0.75rem; margin-top: 1rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 1rem; }
    </style>
</head>
<body>
    <h1>Machine Setup Dashboard</h1>
    <p class="meta">Auto-refreshes every 30 seconds | $(date)</p>

    <div class="grid">
        <div>
            <h2>Status</h2>
            <div class="card"><pre>$(echo "$status_output" | sed \
                -e 's/\[SUCCESS\]/<span class="success">[SUCCESS]<\/span>/g' \
                -e 's/\[WARN\]/<span class="warn">[WARN]<\/span>/g' \
                -e 's/\[ERROR\]/<span class="error">[ERROR]<\/span>/g' \
                -e 's/\[INFO\]/<span class="info">[INFO]<\/span>/g'
            )</pre></div>
        </div>

        <div>
            <h2>Health Check</h2>
            <div class="card"><pre>$(echo "$health_output" | sed \
                -e 's/\[SUCCESS\]/<span class="success">[SUCCESS]<\/span>/g' \
                -e 's/\[WARN\]/<span class="warn">[WARN]<\/span>/g' \
                -e 's/\[ERROR\]/<span class="error">[ERROR]<\/span>/g' \
                -e 's/\[INFO\]/<span class="info">[INFO]<\/span>/g'
            )</pre></div>
        </div>
    </div>

    <h2>Conflict Detection</h2>
    <div class="card"><pre>$(echo "$conflict_output" | sed \
        -e 's/\[SUCCESS\]/<span class="success">[SUCCESS]<\/span>/g' \
        -e 's/\[WARN\]/<span class="warn">[WARN]<\/span>/g' \
        -e 's/\[ERROR\]/<span class="error">[ERROR]<\/span>/g' \
        -e 's/\[INFO\]/<span class="info">[INFO]<\/span>/g'
    )</pre></div>

    <p class="meta">Served from: $(hostname) | Profile: ${PROFILE:-auto} | Port: ${PORT}</p>
</body>
</html>
HTMLEOF
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Generate and serve an HTML status dashboard on a local web server.

Options:
    -p, --port <port>     Port to serve on (default: 8080)
    --profile <name>      Profile to display (default: auto)
    -h, --help            Show this help message

Examples:
    $(basename "$0")
    $(basename "$0") --port 3000 --profile minimal
EOF
    exit 0
}

main() {
    local port="$PORT"
    export PROFILE="${PROFILE:-auto}"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage ;;
            --port|-p) port="$2"; shift 2 ;;
            --profile) export PROFILE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    log_info "Generating dashboard..."
    generate_html

    log_success "Dashboard ready at: http://localhost:${port}"
    log_info "Press Ctrl+C to stop"

    # Serve
    cd "$SERVE_DIR"
    python3 -m http.server "$port" 2>/dev/null || {
        log_error "python3 not available for serving"
        log_info "Generated HTML at: ${SERVE_DIR}/index.html"
        exit 1
    }
}

# Cleanup on exit
trap 'rm -rf "${SERVE_DIR:-}" 2>/dev/null' EXIT

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
