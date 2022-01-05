#!/bin/bash

user_last="ocs"

sections_register_section "software" "Manages our own LAST software" "user"

function software_enforce() {
    su "${user_last}" -c "fetch-from-github --dir ~"
}

function software_check() {
    su "${user_last}" -c "fetch-from-github --dir ~ --check"
}

function software_policy() {
    cat <<- EOF

    All the LAST computers are both production AND development machines.  As such they
     contain git clones of the relevant software repositories (on github). You

    - $(ansi_underline "${PROG} check software") - checks if the local sources are up-to-date
    - $(ansi_underline "${PROG} enforce software") - pulls the lates sources from the repositories
    
EOF
}