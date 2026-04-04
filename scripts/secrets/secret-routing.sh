#!/usr/bin/env bash
# Secret routing layer — ensures secrets only reach encrypted destinations.
# This file is sourced by the orchestrator; do NOT execute directly.

# Double-source guard
if [[ -n "${_SECRET_ROUTING_SH_LOADED:-}" ]]; then
    return 0
fi
_SECRET_ROUTING_SH_LOADED=1

# Resolve paths relative to this script
_SR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SR_REPO_DIR="${REPO_DIR:-$(cd "$_SR_SCRIPT_DIR/../.." && pwd)}"

# Source dependencies
# shellcheck source=../lib/common.sh
source "${_SR_REPO_DIR}/scripts/lib/common.sh"
# shellcheck source=../ini-parser.sh
source "${_SR_REPO_DIR}/scripts/ini-parser.sh"

# Default gitattributes location
_SR_GITATTRIBUTES="${_SR_REPO_DIR}/dotfiles/.gitattributes"

###############################################################################
# is_git_crypt_protected <relative_path> [gitattributes_file]
#
# Returns 0 if the path matches a filter=git-crypt rule, 1 otherwise.
###############################################################################
is_git_crypt_protected() {
    local rel_path="$1"
    local gitattr="${2:-$_SR_GITATTRIBUTES}"

    if [[ ! -f "$gitattr" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        # Skip empty lines, comments, and negation rules
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" == *"!filter"* ]] && continue
        # Only consider git-crypt filter lines
        [[ "$line" == *"filter=git-crypt"* ]] || continue

        # Extract the glob pattern (first whitespace-delimited token)
        local pattern
        pattern="${line%% *}"

        # Convert gitattributes glob to bash regex
        local regex
        regex="$(_glob_to_regex "$pattern")"

        if [[ "$rel_path" =~ ^${regex}$ ]]; then
            return 0
        fi
    done < "$gitattr"

    return 1
}

# Convert a gitattributes glob pattern to a bash extended regex.
_glob_to_regex() {
    local glob="$1"
    local regex=""
    local i=0
    local len=${#glob}

    while (( i < len )); do
        local c="${glob:$i:1}"
        local next="${glob:$((i+1)):1}"

        case "$c" in
            '*')
                if [[ "$next" == '*' ]]; then
                    # Peek past the two stars
                    local after="${glob:$((i+2)):1}"
                    if [[ "$after" == '/' ]]; then
                        # **/ matches zero or more directory components
                        regex+="(.+/)?"
                        i=$((i + 3))
                    else
                        # ** at end matches everything
                        regex+=".+"
                        i=$((i + 2))
                    fi
                else
                    # Single * matches anything except /
                    regex+="[^/]*"
                    i=$((i + 1))
                fi
                ;;
            '.')
                regex+="\\."
                i=$((i + 1))
                ;;
            '?')
                regex+="[^/]"
                i=$((i + 1))
                ;;
            '[')
                # Pass through character classes
                regex+="["
                i=$((i + 1))
                ;;
            ']')
                regex+="]"
                i=$((i + 1))
                ;;
            '+'|'('|')'|'{'|'}'|'^'|'$'|'|')
                regex+="\\${c}"
                i=$((i + 1))
                ;;
            *)
                regex+="$c"
                i=$((i + 1))
                ;;
        esac
    done

    printf '%s' "$regex"
}

###############################################################################
# _is_inside_repo <absolute_path>
#
# Returns 0 if the path is under REPO_DIR, 1 otherwise.
###############################################################################
_is_inside_repo() {
    local abs_path="$1"
    [[ "$abs_path" == "${_SR_REPO_DIR}"/* ]]
}

###############################################################################
# _get_repo_relative_path <absolute_path>
#
# Prints the path relative to REPO_DIR.
###############################################################################
_get_repo_relative_path() {
    local abs_path="$1"
    printf '%s' "${abs_path#"${_SR_REPO_DIR}"/}"
}

###############################################################################
# _require_git_crypt <absolute_path> [gitattributes_file]
#
# Fails (returns 1) if path is inside the repo but NOT git-crypt protected.
###############################################################################
_require_git_crypt() {
    local abs_path="$1"
    local gitattr="${2:-$_SR_GITATTRIBUTES}"

    if _is_inside_repo "$abs_path"; then
        local rel
        rel="$(_get_repo_relative_path "$abs_path")"
        if ! is_git_crypt_protected "$rel" "$gitattr"; then
            log_error "BLOCKED: '$rel' is inside the repo but NOT git-crypt protected"
            return 1
        fi
    fi
    return 0
}

###############################################################################
# route_to_ini <value> <dest_file> <section> <key>
#
# Update a key in an INI config file. Checks git-crypt protection for repo
# files. NEVER logs the secret value.
###############################################################################
route_to_ini() {
    local value="$1"
    local dest_file="$2"
    local section="$3"
    local key="$4"

    # Resolve to absolute path
    if [[ "$dest_file" != /* ]]; then
        dest_file="${_SR_REPO_DIR}/${dest_file}"
    fi

    # Safety check
    if ! _require_git_crypt "$dest_file"; then
        return 1
    fi

    log_info "Writing secret to INI: [${section}] ${key} in ${dest_file}"

    # If file does not exist, create it with the section and key
    if [[ ! -f "$dest_file" ]]; then
        printf '[%s]\n%s = %s\n' "$section" "$key" "$value" > "$dest_file"
        return 0
    fi

    # Check if section exists
    if ! grep -q "^\\[${section}\\]" "$dest_file"; then
        # Append new section and key
        printf '\n[%s]\n%s = %s\n' "$section" "$key" "$value" >> "$dest_file"
        return 0
    fi

    # Check if key exists in section
    local key_exists=false
    local in_section=false
    while IFS= read -r check_line; do
        if [[ "$check_line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == true ]]; then
                break
            fi
            continue
        fi
        if [[ "$in_section" == true && "$check_line" =~ ^[[:space:]]*${key}[[:space:]]*= ]]; then
            key_exists=true
            break
        fi
    done < "$dest_file"

    if [[ "$key_exists" == true ]]; then
        # Replace existing key using sed with section range
        local escaped_key
        escaped_key=$(printf '%s' "$key" | sed 's/[.[\*^$()+?{|]/\\&/g')
        local escaped_value
        escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
        sed -i.bak "/^\\[${section}\\]/,/^\\[/ s/^[[:space:]]*${escaped_key}[[:space:]]*=.*/${key} = ${escaped_value}/" "$dest_file"
        rm -f "${dest_file}.bak"
    else
        # Add key after section header
        local escaped_section
        escaped_section=$(printf '%s' "$section" | sed 's/[.[\*^$()+?{|]/\\&/g')
        sed -i.bak "/^\\[${escaped_section}\\]/a\\
${key} = ${value}" "$dest_file"
        rm -f "${dest_file}.bak"
    fi
}

###############################################################################
# route_to_file <value> <dest_file> <mode>
#
# Write a secret to a file. Files inside the repo must be git-crypt protected.
# Files outside the repo (e.g. ~/.ssh/) are allowed.
# Writes to a temp file first, then moves into place.
###############################################################################
route_to_file() {
    local value="$1"
    local dest_file="$2"
    local mode="${3:-0600}"

    # Resolve to absolute path
    if [[ "$dest_file" != /* ]]; then
        dest_file="${_SR_REPO_DIR}/${dest_file}"
    fi

    # Safety check
    if ! _require_git_crypt "$dest_file"; then
        return 1
    fi

    log_info "Writing secret to file: ${dest_file} (mode=${mode})"

    # Ensure parent directory exists
    local parent_dir
    parent_dir="$(dirname "$dest_file")"
    mkdir -p "$parent_dir"

    # Write to temp file first, then move
    local tmp_file
    tmp_file="$(mktemp)"
    chmod 0600 "$tmp_file"
    printf '%s' "$value" > "$tmp_file"

    mv "$tmp_file" "$dest_file"
    chmod "$mode" "$dest_file"
}

###############################################################################
# route_to_env <value> <var_name>
#
# Export a secret as an environment variable. No disk writes.
###############################################################################
route_to_env() {
    local value="$1"
    local var_name="$2"

    log_info "Exporting secret to env var: ${var_name}"
    export "${var_name}=${value}"
}

###############################################################################
# route_secret <value> <dest_type> <dest_file> <dest_section> <dest_key>
#              <dest_var> <dest_mode>
#
# Dispatcher — calls the right route function based on dest_type.
###############################################################################
route_secret() {
    local value="$1"
    local dest_type="$2"
    local dest_file="${3:-}"
    local dest_section="${4:-}"
    local dest_key="${5:-}"
    local dest_var="${6:-}"
    local dest_mode="${7:-0600}"

    case "$dest_type" in
        ini)
            route_to_ini "$value" "$dest_file" "$dest_section" "$dest_key"
            ;;
        file)
            route_to_file "$value" "$dest_file" "$dest_mode"
            ;;
        env)
            route_to_env "$value" "$dest_var"
            ;;
        *)
            log_error "Unknown destination type: ${dest_type}"
            return 1
            ;;
    esac
}
