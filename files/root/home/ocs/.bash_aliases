#!/bin/bash

# get the current vim version
read -r _ _ _ _ vimver _ <<< "$(vim --version | grep '^VIM' | tr -d '.')"
#shellcheck disable=SC2139
alias ++="vim -u /usr/share/vim/vim${vimver}/macros/less.vim"
unset vimver

alias  p=pwd
alias  u=users
alias  d=dirs
alias  p=pwd
alias  '+'=less
alias  l='ls -FC --color=auto'
alias pu=pushd
alias po=popd
alias  j='jobs -l'
alias rm='/bin/rm -i'
alias di='/bin/ls -l --color=auto'
alias vi=vim
alias     grep="grep -E --color=auto"
alias pcregrep="pcregrep --color=auto -M"

export LESS="-ceFi"

if [ "$(id -un)" == root ]; then
    alias s=suspend
else
    alias s='%sudo'
fi

# let status change of background jobs be displayed immediately
set -b

#
# Some convenience shortcuts
#
this_site="01"
this_mount=$(hostname -s | sed -e 's;last;;' -e 's;[ew]$;;')
declare -A cameras_by_quadrant=(
    [NE]="/last${this_mount}e/data1/archive/LAST.${this_site}.${this_mount}.01"
    [SE]="/last${this_mount}e/data2/archive/LAST.${this_site}.${this_mount}.02"
    [SW]="/last${this_mount}w/data1/archive/LAST.${this_site}.${this_mount}.03"
    [NW]="/last${this_mount}w/data2/archive/LAST.${this_site}.${this_mount}.04"
)

for key in ${!cameras_by_quadrant[*]}; do
    eval "alias cdcam${key}=\"cd ${cameras_by_quadrant[${key}]}\""
    eval "alias cdcam${key,,}=\"cd ${cameras_by_quadrant[${key}]}\""
done

declare -A cameras_by_number=(
    [1]="/last${this_mount}e/data1/archive/LAST.${this_site}.${this_mount}.01"
    [2]="/last${this_mount}e/data2/archive/LAST.${this_site}.${this_mount}.02"
    [3]="/last${this_mount}w/data1/archive/LAST.${this_site}.${this_mount}.03"
    [4]="/last${this_mount}w/data2/archive/LAST.${this_site}.${this_mount}.04"
)

for key in ${!cameras_by_number[*]}; do
    eval "alias cdcam${key}=\"cd ${cameras_by_number[${key}]}\""
done

unset cameras_by_quadrant cameras_by_number this_mount this_site key

function google_no_proxy() {
    local tmp=$(mktemp -d)

    google-chrome --user-data-dir=${tmp} --new-window --no-proxy-server "${@}" &
    /bin/rm -rf ${tmp}
}
