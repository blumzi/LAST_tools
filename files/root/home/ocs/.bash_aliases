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
this_mount=$(hostname -s | sed -e 's;last;;' -e 's;[ew]$;;')
read -r -a cameras <<< "$(find /last0* -maxdepth 3 -name "LAST.01.${this_mount}.*" -type d 2>/dev/null | sort -t . -n)"
for (( i = 1 ; i <= ${#cameras[*]}; i++ )); do
    eval "alias cdcam${i}=\"cd ${cameras[${i}-1]}\""
done

unset cameras this_mount