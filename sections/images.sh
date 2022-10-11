#!/bin/bash

module_include lib/message
module_include lib/sections

sections_register_section "images" "Handles LAST images"

function images_policy() {
    cat <<- EOF
    
    This section handles the images produces by the LAST project

    Typical issues handled by this section:
     - Feeding incoming images to any open last-ds9 viewers
     - Shipping the images to a central archive
     - Deleting old images

EOF
}

function images_enforce() {
    service_enforce last-ds9-feeder lastx
}

function images_check() {
    service_check last-ds9-feeder lastx
}