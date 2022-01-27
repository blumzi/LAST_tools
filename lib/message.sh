#!/bin/bash

module_include lib/ansi

# top process may (or may not) set the --quiet option
if [ ! "${LAST_TOOL_QUIET}" ]; then
    export LAST_TOOL_QUIET=false
fi

if [ ! "${LAST_TOOL_DONTLOG}" ]; then
    export LAST_TOOL_DONTLOG=false
fi

function message_init() {
    :
}

function message_log() {
    local message="${1}"

    if ! ${LAST_TOOL_DONTLOG}; then
        logger -t "${PROG}" "${message}"
    fi
}

# [SECT] section
function message_section() {
    if ! ${LAST_TOOL_QUIET}; then
        echo -e "\n[$(ansi_bright_blue SECT)] $( ansi_bright_blue "${*}" )"
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
    echo "[INFO] ${*}"

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[INFO] ${*}"
    fi
}

# red mesage + optionally kill top shell process
function message_fatal() {    
    echo -e "${PROG}: $(ansi_bright_red FATAL:) $(ansi_bold "${*}")" >&2
    if [ "${LAST_TOOL_PID}" ]; then
        kill -SIGTERM "${LAST_TOOL_PID}" >& /dev/null
    fi

    if ! ${LAST_TOOL_DONTLOG}; then
        message_log "[FATAL] ${*}"
    fi
}