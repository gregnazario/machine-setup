# Nushell Configuration (Full)
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
        algorithm: prefix
    }
    history: {
        max_size: 50000
        sync_on_enter: true
        file_format: "sqlite"
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
        {
            name: history_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
            source: {|| history}
        }
    ]
}

# Aliases
alias ll = ls -l
alias la = ls -a
alias l = ls
alias .. = cd ..
alias ... = cd ../..
alias cat = bat
alias find = fd
alias grep = rg
alias du = dust
alias ps = procs

# Custom functions
def "myip" [] {
    curl -s ifconfig.me
}

def "mkcd" [dir: string] {
    mkdir $dir
    cd $dir
}

def "weather" [] {
    curl wttr.in
}

# Starship prompt (if installed)
# source ~/.cache/starship/init.nu
