#!/bin/bash

module_include lib/ansi

# top process may (or may not) set the --quiet option
if [ ! "${LAST_INSTALLATION_QUIET}" ]; then
    export LAST_INSTALLATION_QUIET=false
fi

# section header
function message_section() {
    if ! ${LAST_INSTALLATION_QUIET}; then
        echo -e "    Section: $( ansi_underline "${*}" )"
    fi
}

# [ OK ] message
function message_success {
    if ! ${LAST_INSTALLATION_QUIET}; then
        echo -e "[$( ansi_bright_green " OK " )] ${*}"
    fi
}

# [FAIL] message
function message_failure {        
    if ! ${LAST_INSTALLATION_QUIET}; then
        echo -e "[$( ansi_bright_red FAIL )] ${*}"
    fi
}

# [WARN] message
function message_warning {
    if ! ${LAST_INSTALLATION_QUIET}; then
        echo -e "[$( ansi_bright_yellow WARN )] ${*}" >&2
    fi
}

# plain message
function message_info {
    echo "       ${*}"
}

# red mesage + optionally kill top shell process
function message_fatal() {    
    echo -e "FATAL: $( ansi_bright_red "${@}" )" >&2
    if [ "${LAST_TOOL_PID}" ]; then
        kill "${LAST_TOOL_PID}"
    fi
}