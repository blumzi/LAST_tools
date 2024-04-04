#!/bin/bash

module_include lib/user
module_include lib/macmap
module_include lib/messages

sections_register_section "crontab" "Handles crontabs" ""

function crontab_enforce() {
    
    {
        if macmap_this_is_last0; then
            echo "0  7 * * * /usr/local/share/last-tool/bin/last-pipeline-digest"
        fi
        echo "0  8 * * * /usr/local/share/last-tool/bin/last-backup --all --remove --force"
        echo "0 12 * * * /usr/local/share/last-tool/bin/last-compress-raw-images"
    } | crontab -u ${user_name} -
    message_success "crontab: Updated crontab for user \"${user_name}\""
}

function crontab_check() {
    local expected found pattern ret

    pattern='last-(backup|compress-raw-images|pipeline-digest)'
    if macmap_this_is_last0; then
        expected=3
    else
        expected=2
    fi

    ret=0
    found=$( crontab -l | egrep  --count 'last-(backup|compress-raw-images)' )
    if (( found == expected )); then
        message_success "crontab: found ${expected} crontab lines"
    else
        message_failure "crontab: found only ${found} lines (expected: ${expected})"
        (( ret++ ))
    fi

    return ${ret}
}

function crontab_policy() {
    cat <<- EOF

    A few activities are performed periodically via cron(8).

    This section maintains the respective crontab(s)

EOF
}
