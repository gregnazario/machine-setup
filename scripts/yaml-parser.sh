#!/usr/bin/env bash

yaml_get() {
    local yaml_content="$1"
    local path="$2"
    local default="${3:-}"
    
    local result
    result=$(echo "$yaml_content" | _yaml_extract "$path")
    
    if [[ -z "$result" || "$result" == "null" ]]; then
        echo "$default"
    else
        echo "$result"
    fi
}

_yaml_extract() {
    local path="$1"
    local current_key=""
    local in_list=false
    local list_index=0
    local depth=0
    local target_depth=0
    local found_value=""
    local found=false
    local path_parts
    local current_path_index=0
    
    IFS='.' read -ra path_parts <<< "$path"
    local num_parts=${#path_parts[@]}
    
    if [[ $num_parts -eq 0 ]]; then
        cat
        return
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ "$stripped" =~ ^-[[:space:]](.*)$ ]]; then
            local item="${BASH_REMATCH[1]}"
            
            if [[ $line_depth -eq $target_depth && $found == true ]]; then
                if [[ $current_path_index -lt $num_parts ]]; then
                    if [[ "$item" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
                        local obj_key="${BASH_REMATCH[1]}"
                        local obj_val="${BASH_REMATCH[2]}"
                        
                        if [[ "$obj_key" == "${path_parts[$current_path_index]}" ]]; then
                            if [[ $current_path_index -eq $((num_parts - 1)) ]]; then
                                echo "$obj_val"
                                return
                            fi
                            ((current_path_index++))
                            target_depth=$((line_depth + 1))
                        fi
                    fi
                fi
            fi
        elif [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            if [[ $line_depth -lt $target_depth ]]; then
                found=false
                current_path_index=0
                target_depth=0
            fi
            
            if [[ $line_depth -eq $target_depth || $target_depth -eq 0 ]]; then
                if [[ "$key" == "${path_parts[$current_path_index]}" ]]; then
                    if [[ $current_path_index -eq $((num_parts - 1)) ]]; then
                        if [[ -n "$value" && "$value" != "null" ]]; then
                            echo "$value"
                            return
                        else
                            found=true
                            target_depth=$((line_depth + 1))
                            ((current_path_index++)) || true
                        fi
                    else
                        found=true
                        target_depth=$((line_depth + 1))
                        ((current_path_index++)) || true
                    fi
                else
                    found=false
                    current_path_index=0
                    target_depth=0
                fi
            fi
        fi
    done
    
    if [[ $found == true && $current_path_index -ge $num_parts ]]; then
        :
    fi
}

yaml_get_list() {
    local yaml_content="$1"
    local path="$2"
    
    echo "$yaml_content" | _yaml_extract_list "$path"
}

_yaml_extract_list() {
    local path="$1"
    local path_parts
    local current_path_index=0
    local target_depth=0
    local found=false
    local collecting=false
    local list_depth=0
    
    IFS='.' read -ra path_parts <<< "$path"
    local num_parts=${#path_parts[@]}
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ "$stripped" =~ ^([^:]+):[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            
            if [[ $line_depth -lt $list_depth ]]; then
                collecting=false
            fi
            
            if [[ $collecting == false ]]; then
                if [[ "$key" == "${path_parts[$current_path_index]}" ]]; then
                    if [[ $current_path_index -eq $((num_parts - 1)) ]]; then
                        collecting=true
                        list_depth=$((line_depth + 1))
                    else
                        ((current_path_index++)) || true
                        target_depth=$((line_depth + 1))
                        found=true
                    fi
                else
                    current_path_index=0
                    found=false
                fi
            fi
        elif [[ "$stripped" =~ ^-[[:space:]]+(.*)$ ]]; then
            local item="${BASH_REMATCH[1]}"
            if [[ $collecting == true && $line_depth -eq $list_depth ]]; then
                echo "$item"
            fi
        fi
    done
}

yaml_get_objects() {
    local yaml_content="$1"
    local path="$2"
    
    echo "$yaml_content" | _yaml_extract_objects "$path"
}

_yaml_extract_objects() {
    local path="$1"
    local path_parts
    local current_path_index=0
    local collecting=false
    local list_depth=0
    local current_object=""
    local in_object=false
    
    IFS='.' read -ra path_parts <<< "$path"
    local num_parts=${#path_parts[@]}
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ "$stripped" =~ ^([^:]+):[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            
            if [[ $in_object == true && $line_depth -le $list_depth ]]; then
                if [[ -n "$current_object" ]]; then
                    echo "$current_object"
                fi
                current_object=""
                in_object=false
            fi
            
            if [[ $collecting == false ]]; then
                if [[ "$key" == "${path_parts[$current_path_index]}" ]]; then
                    if [[ $current_path_index -eq $((num_parts - 1)) ]]; then
                        collecting=true
                        list_depth=$((line_depth + 1))
                    else
                        ((current_path_index++)) || true
                    fi
                else
                    current_path_index=0
                fi
            fi
        elif [[ "$stripped" =~ ^-[[:space:]]*$ ]]; then
            if [[ $in_object == true ]]; then
                if [[ -n "$current_object" ]]; then
                    echo "$current_object"
                fi
                current_object=""
            fi
            in_object=true
        elif [[ $in_object == true && "$stripped" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            local obj_key="${BASH_REMATCH[1]}"
            local obj_val="${BASH_REMATCH[2]}"
            if [[ -n "$current_object" ]]; then
                current_object="$current_object
$obj_key: $obj_val"
            else
                current_object="$obj_key: $obj_val"
            fi
        fi
    done
    
    if [[ $in_object == true && -n "$current_object" ]]; then
        echo "$current_object"
    fi
}

yaml_object_get() {
    local object="$1"
    local key="$2"
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^${key}:[[:space:]]*(.*)$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    done <<< "$object"
}

yaml_merge() {
    local base="$1"
    local overlay="$2"
    
    _yaml_deep_merge "$base" "$overlay" 0
}

_yaml_deep_merge() {
    local base="$1"
    local overlay="$2"
    local depth="$3"
    
    local result=""
    local -A processed_keys
    
    local base_keys=$(_yaml_get_top_keys "$base" "$depth")
    local overlay_keys=$(_yaml_get_top_keys "$overlay" "$depth")
    local all_keys=$(echo -e "$base_keys\n$overlay_keys" | sort -u)
    
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        
        local base_section
        local overlay_section
        base_section=$(_yaml_extract_section_at_depth "$base" "$key" "$depth")
        overlay_section=$(_yaml_extract_section_at_depth "$overlay" "$key" "$depth")
        
        if [[ -z "$base_section" ]]; then
            result="$result$overlay_section
"
        elif [[ -z "$overlay_section" ]]; then
            result="$result$base_section
"
        else
            local base_has_nested=$(_yaml_has_nested_content "$base_section")
            local overlay_has_nested=$(_yaml_has_nested_content "$overlay_section")
            
            if [[ "$base_has_nested" == "true" && "$overlay_has_nested" == "true" ]]; then
                local base_is_list=$(_yaml_is_list_section "$base_section")
                local overlay_is_list=$(_yaml_is_list_section "$overlay_section")
                
                if [[ "$base_is_list" == "true" || "$overlay_is_list" == "true" ]]; then
                    result="$result$overlay_section
"
                else
                    local base_nested=$(_yaml_get_nested_content "$base_section")
                    local overlay_nested=$(_yaml_get_nested_content "$overlay_section")
                    local merged_nested=$(_yaml_deep_merge "$base_nested" "$overlay_nested" $((depth + 1)))
                    local indent=$(printf '%*s' $((depth * 2)) '')
                    result="$result${indent}${key}:
$merged_nested
"
                fi
            else
                result="$result$overlay_section
"
            fi
        fi
        processed_keys["$key"]=1
    done <<< "$all_keys"
    
    echo "$result"
}

_yaml_get_top_keys() {
    local yaml="$1"
    local depth="$2"
    local indent=$(printf '%*s' $((depth * 2)) '')
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ $line_depth -eq $depth && "$stripped" =~ ^([^:]+): ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done <<< "$yaml"
}

_yaml_extract_section_at_depth() {
    local yaml="$1"
    local section_key="$2"
    local depth="$3"
    local indent=$(printf '%*s' $((depth * 2)) '')
    
    local in_section=false
    local section_content=""
    local section_start_line=""
    local section_has_value=false
    
    while IFS= read -r line; do
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local leading_spaces=$((${#line} - ${#stripped}))
        local line_depth=$((leading_spaces / 2))
        
        if [[ $line_depth -eq $depth && "$stripped" =~ ^${section_key}: ]]; then
            in_section=true
            section_start_line="$line"
            if [[ "$stripped" =~ ^${section_key}:[[:space:]]*(.+)$ ]]; then
                section_has_value=true
            fi
            continue
        fi
        
        if [[ $in_section == true ]]; then
            if [[ $section_has_value == true ]]; then
                break
            fi
            if [[ $line_depth -gt $depth ]]; then
                if [[ -z "$section_content" ]]; then
                    section_content="$section_start_line
$line"
                else
                    section_content="$section_content
$line"
                fi
            else
                break
            fi
        fi
    done <<< "$yaml"
    
    if [[ $section_has_value == true ]]; then
        echo "$section_start_line"
    elif [[ -n "$section_content" ]]; then
        echo "$section_content"
    fi
}

_yaml_has_nested_content() {
    local section="$1"
    local lines=$(echo "$section" | wc -l)
    
    if [[ $lines -gt 1 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

_yaml_is_list_section() {
    local section="$1"
    local first_line=true
    
    while IFS= read -r line; do
        if [[ "$first_line" == true ]]; then
            first_line=false
            continue
        fi
        local stripped="${line#"${line%%[![:space:]]*}"}"
        if [[ "$stripped" =~ ^-[[:space:]] ]]; then
            echo "true"
            return
        else
            echo "false"
            return
        fi
    done <<< "$section"
    
    echo "false"
}

_yaml_get_nested_content() {
    local section="$1"
    local first_line=true
    
    while IFS= read -r line; do
        if [[ "$first_line" == true ]]; then
            first_line=false
            continue
        fi
        echo "$line"
    done <<< "$section"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        test)
            echo "Testing YAML parser..."
            cat
            ;;
        *)
            echo "Usage: source $0"
            echo "  This file provides YAML parsing functions for bash scripts"
            ;;
    esac
fi
