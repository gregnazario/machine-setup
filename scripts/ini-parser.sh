#!/usr/bin/env bash

# Simple INI Parser for Bash
# No external dependencies required

ini_get() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="${4:-}"

    local value=""
    local in_section=false

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue

        # Section header
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == true ]]; then
                # Hit the next section, stop searching
                break
            fi
            continue
        fi

        # Key-value pair within our section
        if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local found_key="${BASH_REMATCH[1]}"
            local found_value="${BASH_REMATCH[2]}"
            # Trim whitespace
            found_key=$(echo "$found_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            found_value=$(echo "$found_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$found_key" == "$key" ]]; then
                value="$found_value"
                # Don't break - last match wins (for merged files)
            fi
        fi
    done < "$file"

    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

ini_get_list() {
    local file="$1"
    local section="$2"
    local key="$3"

    local in_section=false

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue

        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == true ]]; then
                break
            fi
            continue
        fi

        if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local found_key="${BASH_REMATCH[1]}"
            local found_value="${BASH_REMATCH[2]}"
            found_key=$(echo "$found_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            found_value=$(echo "$found_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$found_key" == "$key" ]]; then
                echo "$found_value"
            fi
        fi
    done < "$file"
}

ini_get_sections() {
    local file="$1"
    grep "^\[" "$file" 2>/dev/null | sed 's/\[//;s/\]//'
}

ini_get_all_keys() {
    local file="$1"
    local section="$2"

    local in_section=false

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue

        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            elif [[ "$in_section" == true ]]; then
                break
            fi
            continue
        fi

        if [[ "$in_section" == true && "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*= ]]; then
            local found_key="${BASH_REMATCH[1]}"
            echo "$found_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
        fi
    done < "$file"
}

ini_merge() {
    local base_file="$1"
    local overlay_file="$2"
    local output_file="${3:-}"

    local tmp_file
    tmp_file=$(mktemp)

    # Copy base file
    cp "$base_file" "$tmp_file"

    # Read overlay sections and keys
    local current_section=""
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]] && continue

        # Section header
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            # Add section if it doesn't exist
            if ! grep -q "^\[${current_section}\]" "$tmp_file"; then
                echo "" >> "$tmp_file"
                echo "[${current_section}]" >> "$tmp_file"
            fi
            continue
        fi

        # Key-value pair
        if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Trim spaces from key and value
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Check if key exists in section using proper section-bounded search
            local key_exists=false
            local in_section=false
            while IFS= read -r check_line; do
                if [[ "$check_line" =~ ^\[([^]]+)\] ]]; then
                    if [[ "${BASH_REMATCH[1]}" == "$current_section" ]]; then
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
            done < "$tmp_file"

            if [[ "$key_exists" == true ]]; then
                # Replace existing key using sed with section range
                local escaped_key
                escaped_key=$(printf '%s' "$key" | sed 's/[.[\*^$()+?{|]/\\&/g')
                local escaped_value
                escaped_value=$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')
                sed -i.bak "/^\[${current_section}\]/,/^\[/ s/^[[:space:]]*${escaped_key}[[:space:]]*=.*/${key} = ${escaped_value}/" "$tmp_file"
                rm -f "${tmp_file}.bak"
            else
                # Add key after section header
                local escaped_section
                escaped_section=$(printf '%s' "$current_section" | sed 's/[.[\*^$()+?{|]/\\&/g')
                sed -i.bak "/^\[${escaped_section}\]/a\\
${key} = ${value}" "$tmp_file"
                rm -f "${tmp_file}.bak"
            fi
        fi
    done < "$overlay_file"

    if [[ -n "$output_file" ]]; then
        mv "$tmp_file" "$output_file"
    else
        cat "$tmp_file"
        rm "$tmp_file"
    fi
}

# Test function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        test)
            echo "Testing INI parser..."
            ;;
        *)
            echo "Usage: source $0"
            echo "  Provides INI parsing functions for bash scripts"
            echo ""
            echo "Functions:"
            echo "  ini_get <file> <section> <key> [default]"
            echo "  ini_get_list <file> <section> <key>"
            echo "  ini_get_sections <file>"
            echo "  ini_get_all_keys <file> <section>"
            echo "  ini_merge <base_file> <overlay_file> [output_file]"
            ;;
    esac
fi
