#!/usr/bin/env bash

empty()
{
    [[ "${#1}" == 0 ]] && return 0 || return 1
}

isset ()
{
    [[ ! "${#1}" == 0 ]] && return 0 || return 1
}

on ()
{
    func="$1";
    shift;
    for sig in "$@";
    do
        trap "$func $sig" "$sig";
    done
}

values ()
{
    echo "$2"
}

last ()
{
    [[ ! -n $1 ]] && return 1;
    echo "$(eval "echo \${$1[@]:(-1)}")"
}

