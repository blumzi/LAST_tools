#!/bin/bash

module_include lib/message
module_include lib/sections

declare matlab_mac matlab_file_installation_key

function matlab_init() {
    sections_register_section "matlab" "Manages the MATLAB installation"
}

function matlab_start() {
    :
}

function matlab_configure() {
    :
}

function matlab_check() {
    :
}