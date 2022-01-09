#!/bin/bash

module_include lib/container

sections_register_section "software" "Manages our own LAST software" "user"

function software_enforce() {
    local wine_dir="/home/${user_last}/.wine"

    su "${user_last}" -c "fetch-from-github --dir /home/${user_last}"

    if [ ! -d "${wine_dir}" ] && container_has "${selected_container}" wine; then
        su "${user_last}" -c "cd /home/${user_last}; tar xzf ${selected_container}/wine.tgz"
    fi
}

function software_check() {
    local -i ret=0
    local wine_dir="/home/${user_last}/.wine"

    su "${user_last}" -c "fetch-from-github --dir /home/${user_last} --check"
    (( ret += $? ))

    if [ -d "${wine_dir}" ]; then
        message_success "The directory ${wine_dir} exists"
    else
        message_failure "The ${wine_dir} directory does not exist"
        (( ret++ ))
    fi

    return $(( ret ))
}

function software_policy() { 
    cat <<- EOF

    All the LAST computers are both production AND development machines.  As such they
     contain git clones of the relevant software repositories (on github). You

    - $(ansi_underline "${PROG} check software") - checks if the local sources are up-to-date
    - $(ansi_underline "${PROG} enforce software") - pulls the latest sources from the repositories
    
    Software repsitories:

EOF
    su "${user_last}" -c "fetch-from-github --dir ~ --list"
    echo ""

    cat <<- EOF
    Other softwares covered by this section:
     - A 'wine' repository for the "Copley Motion" windows software
EOF
}