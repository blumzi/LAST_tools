#!/bin/bash

module_include lib/logs
module_include lib/macmap
module_include lib/logs

sections_register_section "logs" "Handles the LAST logs" ""

function logs_enforce() {
    local tmp=$(mktemp)
    local config_file="/etc/rsyslog.conf"
    local on_last=false
    
    if macmap_this_is_last0; then
        on_last0=true
    fi

    {
        if ${on_last0}; then
            grep -v 'DynamicFile' ${config_file}
            echo '# DynamicFile template for receiving remote LAST logs'
            echo '$template DynamicFile,"'${logs_remote_dir}'/%FROMHOST%/%syslogfacility-text%.log"'
            echo '*.* -?DynamicFile'

        else
            grep -v '^\*\.\*' ${config_file}
            echo '*.* @last0'
        fi
    } < ${config_file} > ${tmp}
    /bin/mv ${tmp} ${config_file}

    message_success "Updated the \"${config_file}\" configuration file"
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
    local on_last=false

    if macmap_this_is_last0; then
        on_last0=true
    fi

    if ${on_last0}; then
        pattern="template DynamicFile\.\*${logs_remote_dir}"
    else
        pattern="\*\.\* @last0"
    fi

    if grep -q "${pattern}" ${config_file}; then
        message_success "config: \"${config_file}\" contains \"${pattern}\"."
    else
        message_failure "config: \"${config_file}\" does not contain \"${pattern}\"."
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
        if find /var/log/remote \! -readable -a \! -executable 2>/dev/null; then
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
