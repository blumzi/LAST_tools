#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "paths" "Manages various paths"

#
# Checks the required LAST paths
#

# TODO: Cross mount of data1 and data2

function paths_enforce() {
    :
}

function paths_check() {
    :
}