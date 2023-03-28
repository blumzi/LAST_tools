#!/bin/bash

module_include lib/logs
module_include lib/macmap
module_include lib/logs

sections_register_section "logs" "Handles the LAST logs" ""

function logs_enforce() {
    local tmp=$(mktemp)
    local config_file="/etc/rsyslog.conf"
    local on_last0=false
    
    if macmap_this_is_last0; then
        on_last0=true
    fi

    {
        if ${on_last0}; then
            grep -v 'LAST' ${config_file}
            echo '# LAST messages (with local0 facility)'
            echo '$template LASTmessages,"'${logs_remote_dir}'/%FROMHOST%/last-messages.log"'
            echo 'local0.* -?LASTmessages'
            echo '# NONLAST messages (all other facilities)'
            echo '$template NONLASTmessages,"'${logs_remote_dir}'/%FROMHOST%/last-messages.log"'
            echo 'kern,user,mail,daemon,auth,syslog,lpr,news,uucp,cron,authpriv,ftp,local1,local2,local3,local4,local5,local6,local7.* -?NONLASTmessages'
        else
            grep -v '^\*\.\*' ${config_file}
            echo '*.* @last0'
        fi
    } < ${config_file} > ${tmp}
    /bin/mv ${tmp} ${config_file}

    message_success "Updated the \"${config_file}\" configuration file, restarting the rsyslog service"
    systemctl restart rsyslog

    local dir=${logs_global_dir}

    if [ ! -d "${dir}" ]; then
        mkdir -m 775 -p ${dir}
        message_success "directory: \"${dir}\" created"
    else
        message_success "directory: \"${dir}\" exists."
    fi

    local existing_owner="$(stat --format "%U.%G" "${dir}")"
    local wanted_owner="${user_name}.${user_group}"

    if [ "${owner}" != "${wanted_owner}" ]; then
        chown ${wanted_owner} ${dir}
        message_success "directory: \"${dir}\" changed ownership to ${wanted_owner}"
    else
        message_success "directory: \"${dir}\" ownership is ${existing_owner}"
    fi

    local existing_access="$(stat --format "%a" ${dir})"
    local wanted_access=775

    if [ "${access}" != "${wanted_access}" ]; then
        chmod ${wanted_access} ${dir}
        message_success "directory: \"${dir}\" changed access to ${wanted_access}"
    else
        message_success "directory: \"${dir}\" access is ${existing_access}"
    fi

    if ${on_last0}; then
        find ${logs_remote_dir} -type d -exec chmod a+xr {} \; 2>/dev/null
        find ${logs_remote_dir} -type f -exec chmod a+r {} \;  2>/dev/null
        message_success "directory: \"${logs_remote_dir}\" added read and search access"
    fi
}

function logs_check() {
    local pattern
    local config_file="/etc/rsyslog.conf"
    local -i ret=0
    local on_last0=false

    if macmap_this_is_last0; then
        on_last0=true
    fi

    local expected_nlines
    if ${on_last0}; then
        pattern="(LAST|NONLAST)messages"
        expected_nlines=4
    else
        pattern="\*\.\* @last0"
        expected_nlines=1
    fi

    local nlines=$(grep -Ec "${pattern}" ${config_file})
    if [ ${nlines} -eq ${expected_nlines} ]; then
        message_success "config: \"${config_file}\" contains ${expected_nlines} \"${pattern}\" lines."
    else
        message_failure "config: \"${config_file}\" contains ${nlines} \"${pattern}\" lines (instead of ${expected_nlines})."
        (( ret++ ))
    fi

    local dir=${logs_global_dir}
    local -i ret=0

    if [ ! -d "${dir}" ]; then
        message_failure "directory: \"${dir}\" Missing."
        (( ret++ ))
        return 1
    fi
    message_success "directory: \"${dir}\" exists."

    local existing_owner="$(stat --format "%U.%G" "${dir}")"
    local wanted_owner="${user_name}.${user_group}"

    if [ "${existing_owner}" != "${wanted_owner}" ]; then
        message_failure "directory: \"${dir}\" owner is ${existing_owner} instead of ${wanted_owner}"
        (( ret++ ))
    else
        message_success "directory: \"${dir}\" owner is ${existing_owner}"
    fi

    local existing_access="$(stat --format "%a" ${dir})"
    local wanted_access=775

    if [ "${existing_access}" != "${wanted_access}" ]; then
        message_failure "directory: \"${dir}\" access is ${existing_access} instead of ${wanted_access}"
        (( ret++ ))
    else
        message_success "directory: \"${dir}\" access is ${existing_access}"
    fi

    if ${on_last0}; then
        if find ${logs_remote_dir} -type d -a \( \! -readable -o \! -executable \) 2>/dev/null ||
            find ${logs_remote_dir} -type f -a \! -readable 2>/dev/null; then
            message_success "directory: \"${logs_remote_dir}\" and descendants are readable and searchable." 
        else
            message_failure "directory: \"${logs_remote_dir}\" has non-readable or non-searchable descendants"
            (( ret++ ))
        fi
    fi

    return ${ret}
}

function logs_policy() {
    cat <<- EOF

    Local logs are either sent to files under ${logs_global_dir} or sent to syslog, or both :-).
     They are also sent to last0.
    
    On last0 rsyslog listens for UDP log messages on port 514 and saves them under ${logs_remote_dir}/<HOSTNAME>

    We are considering forwarding them to a machine at WIS.

EOF
}
