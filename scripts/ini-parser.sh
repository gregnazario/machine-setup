#!/usr/bin/env bash

# Simple INI Parser for Bash
# No external dependencies required

ini_get() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="${4:-}"
    
    local value
    value=$(grep -A 100 "^\[${section}\]" "$file" 2>/dev/null | \
            grep "^[[:space:]]*${key}[[:space:]]*=" | \
            head -1 | \
            cut -d'=' -f2- | \
            sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
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
    
    grep -A 100 "^\[${section}\]" "$file" 2>/dev/null | \
        grep "^[[:space:]]*${key}[[:space:]]*=" | \
        cut -d'=' -f2- | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

ini_get_sections() {
    local file="$1"
    grep "^\[" "$file" 2>/dev/null | sed 's/\[//;s/\]//'
}

ini_get_all_keys() {
    local file="$1"
    local section="$2"
    
    grep -A 100 "^\[${section}\]" "$file" 2>/dev/null | \
        grep -B 100 "^\[" | \
        grep "=" | \
        grep -v "^\[" | \
        cut -d'=' -f1 | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
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
            
            # Escape special characters for sed
            local escaped_key=$(echo "$key" | sed 's/[.[\*^$()+?{|]/\\&/g')
            local escaped_value=$(echo "$value" | sed 's/[&/\]/\\&/g')
            
            # Check if section exists
            if grep -q "^\[${current_section}\]" "$tmp_file"; then
                # Check if key exists in section
                if grep -A 100 "^\[${current_section}\]" "$tmp_file" | grep -B 100 "^\[" | grep -q "^[[:space:]]*${escaped_key}[[:space:]]*="; then
                    # Replace existing key
                    sed -i "/^\[${current_section}\]/,/^\[/ s/^[[:space:]]*${escaped_key}[[:space:]]*=.*/${key} = ${escaped_value}/" "$tmp_file" 2>/dev/null || \
                    sed -i.bak "/^\[${current_section}\]/,/^\[/ s/^[[:space:]]*${escaped_key}[[:space:]]*=.*/${key} = ${escaped_value}/" "$tmp_file"
                else
                    # Add key to existing section
                    sed -i "/^\[${current_section}\]/a ${key} = ${value}" "$tmp_file" 2>/dev/null || \
                    sed -i.bak "/^\[${current_section}\]/a ${key} = ${value}" "$tmp_file"
                fi
            else
                # Add section and key
                echo "" >> "$tmp_file"
                echo "[${current_section}]" >> "$tmp_file"
                echo "${key} = ${value}" >> "$tmp_file"
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
