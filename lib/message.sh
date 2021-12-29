#!/bin/bash

module_include lib/ansi

export message_session

# top process may (or may not) set the --quiet option
if [ ! "${LAST_TOOL_QUIET}" ]; then
    export LAST_TOOL_QUIET=false
fi

if [ ! "${LAST_TOOL_DONTLOG}" ]; then
    export LAST_TOOL_DONTLOG=false
fi

declare message_session

function message_init() {
    :
}

function message_log() {
    local message="${1}"

    if ! ${LAST_TOOL_DONTLOG}; then
        logger -t "${PROG}" "${message}"
    fi
}

# section header
function message_section() {
    if ! ${LAST_TOOL_QUIET}; then
        echo -e "\n    Section: $( ansi_underline "${*}" )\n"
    fi
}

# [ OK ] message
function message_success {
    if ! ${LAST_TOOL_QUIET}; then
        echo -e "[$( ansi_bright_green " OK " )] ${*}"
    fi

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[ OK ] ${*}"
    fi
}

# [FAIL] message
function message_failure {        
    if ! ${LAST_TOOL_QUIET}; then
        echo -e "[$( ansi_bright_red FAIL )] ${*}"
    fi

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[FAIL] ${*}"
    fi
}

# [WARN] message
function message_warning {
    if ! ${LAST_TOOL_QUIET}; then
        echo -e "[$( ansi_bright_yellow WARN )] ${*}" >&2
    fi

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[WARN] ${*}"
    fi
}

# plain message
function message_info {
    echo "       ${*}"

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[INFO] ${*}"
    fi
}

# red mesage + optionally kill top shell process
function message_fatal() {    
    echo -e "FATAL: $( ansi_bright_red "${@}" )" >&2
    if [ "${LAST_TOOL_PID}" ]; then
        kill "${LAST_TOOL_PID}"
    fi

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[FATAL] ${*}"
    fi
}

function message_fatal() {
    echo -e "FATAL: ${ansi_bright_red}${*}${ansi_normal}, Exiting!"
    exit 2
}