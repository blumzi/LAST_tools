#!/bin/bash

module_include lib/message
module_include lib/sections

apt_config_file=/etc/apt/apt.conf

sections_register_section "apt" "Configures Apt"

function apt_enforce() {
    apt update
}

function apt_configure() {

    message_section "Apt"
    
    if [ ! -f ${apt_config_file} ]; then
        mkdir -p "$(dirname "${apt_config_file}")"
        {
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > ${apt_config_file}
    else
        local tmp
        
        tmp=$(mktemp)
        {
            grep -Ev '(Acquire::http::Proxy|Acquire::https::Proxy)' "${apt_config_file}"
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > "${tmp}"
        mv "${tmp}" ${apt_config_file}
    fi
}

function apt_check() {
    local success=false

    message_section "Apt"
    
    if [[ "$(grep -qs '^Acquire::http::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]] &&
        [[ "$(grep -qs '^Acquire::https::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]]; then
        success=true
    fi

    if ${success}; then
        message_success "Apt proxy is well defined"
    else
        message_failure "Apt proxy is not well defined"
    fi
}