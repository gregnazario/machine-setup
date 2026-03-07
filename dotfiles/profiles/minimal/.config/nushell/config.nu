# Nushell Configuration (Minimal)
# Location: ~/.config/nushell/config.nu

let-env config = {
    ls: {
        use_ls_colors: true
        clickable_links: true
    }
    rm: {
        always_trash: false
    }
    table: {
        mode: rounded
        index_mode: always
        trimming: {
            methodology: wrapping
            wrapping_try_keep_words: true
        }
    }
    completions: {
        case_sensitive: false
        quick: true
        partial: true
    }
    history: {
        max_size: 10000
        sync_on_enter: true
        file_format: "plaintext"
    }
    hooks: {
        pre_prompt: [{
            code: "
                let direnv = (direnv export json | from json)
                if ($direnv | length) > 0 {
                    load-env $direnv
                }
            "
        }]
    }
    menus: [
        {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
    ]
}

# Aliases
alias ll = ls -l
alias la = ls -a
alias l = ls
alias .. = cd ..
alias ... = cd ../..
alias grep = grep --color=auto
