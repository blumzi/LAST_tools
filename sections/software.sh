#!/bin/bash

user_last="ocs"

sections_register_section "software" "Manages our own LAST software" "user"

function software_enforce() {
    su "${user_last}" -c "fetch-from-github --dir ~"
}

function software_check() {
    su "${user_last}" -c "fetch-from-github --dir ~ --check"
}