#!/bin/bash

module_include lib/message
module_include lib/sections

apt_config_file=/etc/apt/apt.conf

sections_register_section "apt" "Configures Apt"

function apt_enforce() {
    
    if [ ! -f ${apt_config_file} ]; then
        mkdir -p "$(dirname "${apt_config_file}")"
        {
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > ${apt_config_file}

		message_success "Generated config file ${apt_config_file}"
		message_info "Updating apt ..."
		apt update
    elif [[ "$(grep -s '^Acquire::http::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]] &&
			[[ "$(grep -s '^Acquire::https::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]]; then
			message_success "Config file ${apt_config_file} complies"
			return
	else
        local tmp
        tmp=$(mktemp)
        {
            grep -Ev '(Acquire::http::Proxy|Acquire::https::Proxy)' "${apt_config_file}"
            echo 'Acquire::http::Proxy "http://bcproxy.weizmann.ac.il:8080";'
            echo 'Acquire::https::Proxy "http://bcproxy.weizmann.ac.il:8080";'
        } > "${tmp}"
        mv "${tmp}" ${apt_config_file}

		message_success "Fixed config file ${apt_config_file}"
		message_info "Updating apt ..."
		apt update
    fi
}

function apt_check() {
    local success=false
    
    if [[ "$(grep -s '^Acquire::http::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]] &&
        [[ "$(grep -s '^Acquire::https::Proxy' ${apt_config_file})" == *http://bcproxy.weizmann.ac.il:8080* ]]; then
        success=true
    fi

    if ${success}; then
        message_success "Apt proxy is well defined"
    else
        message_failure "Apt proxy is not well defined"
    fi
}

function apt_policy() {
    cat <<- EOF

    We use the Weizmann Institute's apt proxies, both for http and https.com

    The apt configuration file ${apt_config_file} should reflect this.
    
EOF
}
