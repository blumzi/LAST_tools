#!/bin/bash

module_include lib/ansi

if [ ! "${LAST_INSTALLATION_QUIET}" ]; then
    export LAST_INSTALLATION_QUIET=false
fi


function message_section() {
    if ! ${LAST_INSTALLATION_QUIET}; then
        printf "\n       Section: %s%s%s\n\n" "${ansi_bright_white}" "${*}" ${ansi_normal}""
    fi
}

# "msg [OK]"
function message_success {
    if ! ${LAST_INSTALLATION_QUIET}; then
        printf "[%s OK %s] %s\n" "${ansi_bright_green}" "${ansi_normal}" "${@}"
    fi
}

# "msg [!!]"
function message_failure {        
    if ! ${LAST_INSTALLATION_QUIET}; then
        printf "[%sFAIL%s] %s\n" "${ansi_bright_red}" "${ansi_normal}" "${@}"
    fi
}

# Warning msg in yellow
function message_warning {
    if ! ${LAST_INSTALLATION_QUIET}; then
        printf "[%sWARN%s] %s\n" "${ansi_bright_yellow}" "${ansi_normal}" "${@}"
    fi
}

# Information msg in blue
function message_info {
    printf "       %s\n" "${@}"
}

# Successful completion msg in green
function message_ok {
    echo -e "${ansi_bright_green}${*}${CNRM}"
}

# Error msg in red
function message_error {
    if ! ${QUIET}; then
        echo -e "${ansi_bright_red}${*}${CNRM}"
    fi
}

function message_fatal() {
    echo -e "FATAL: ${ansi_bright_red}${*}${ansi_normal}, Exiting!"
    exit 2
}