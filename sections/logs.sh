#!/bin/bash

module_include lib/logs
module_include lib/macmap
module_include lib/logs

sections_register_section "logs" "Handles forwarding and rotation of the LAST logs and files" ""

function logs_mklogrotate_last0_conf() {
    cat <<- "EOF"
/var/log/remote/*/*.log
{
	rotate 7
	daily
	missingok
	notifempty
	delaycompress
	compress
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
EOF
}

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

    sed -i -e '/imudp/s;^#;;' ${config_file}
    message_success "config: Enabled \"imudp\"."

    message_success "config: Restarting the rsyslog service"
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

        config_file="/etc/logrotate.d/last-logs"
        logs_mklogrotate_last0_conf > ${config_file}
        message_success "logrotate: Overwriten \"${config_file}\"."
    else
        config_file="/etc/logrotate.d/last-logs"
        cat << "EOF" > ${config_file}
/var/log/ocs/api/.logrotate {
    daily
    rotate 1
    missingok
    notifempty
    create 644 ocs ocs
    su ocs ocs
    postrotate
        # Find all subdirectories (max depth 1), sort them by modification time (newest first),
        # skip the first 10, and remove the rest.
        /usr/bin/find /var/log/ocs/api -mindepth 1 -maxdepth 1 -type d -print0 | \
        /usr/bin/xargs -0 -r ls -td | \
        /usr/bin/tail -n +11 | \
        /usr/bin/xargs -r rm -rf
        echo hiho /var/log/ocs/api/.logrotate
    endscript
}

/var/log/last/.logrotate {
    daily
    rotate 1
    missingok
    notifempty
    create 644 ocs ocs
    su ocs ocs
    postrotate
        # Find all subdirectories (max depth 1), sort them by modification time (newest first),
        # skip the first 10, and remove the rest.
        /usr/bin/find /var/log/last -mindepth 1 -maxdepth 1 -type d -print0 | \
        /usr/bin/xargs -0 -r ls -td | \
        /usr/bin/tail -n +11 | \
        /usr/bin/xargs -r rm -rf
        echo hiho /var/log/last/.logrotate
    endscript
}
EOF
        message_success "logrotate: Overwriten \"${config_file}\"."
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

    if grep -q '^#.*imudp' ${config_file}; then
        message_failure "config: \"imudp\" is disabled"
        (( ret++ ))
    else
        message_success "config: \"imudp\" is enabled"
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

        config_file="/etc/logrotate.d/last-logs"
        local tmp=$(mktemp)
        logs_mklogrotate_last0_conf > ${tmp}
        if cmp --quiet ${config_file} ${tmp}; then
            message_success "logrotate: \"${config_file}\" is OK."
        else
            message_failure "logrotate: BAD \"${config_file}\"!"
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
