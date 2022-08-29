#!/bin/bash

module_include lib/service
module_include lib/message

sections_register_section "sensors" "Manages the LAST sensors" "matlab"

function sensors_policy() {
    cat <<- EOF
    
    This section handles the gathering of data from the various LAST sensors using services

    Currenly we get data from:
     - Indoor sensors from one Arduino
     - Outdoor sensors from another Ardiouno
     - A Davis Systems weather station

EOF
}

function sensors_enforce() {
    service_enforce last-meteologger last0
}

function sensors_check() {
    service_check last-meteologger last0
}
