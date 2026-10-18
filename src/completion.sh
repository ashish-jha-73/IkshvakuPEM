# ~/.ikshvaku/completion.sh
# shellcheck shell=bash

_ikshvaku_complete() {
    local cur prev cmds envs

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    cmds="list create activate deactivate install remove init link unlink links status doctor auto run export clone cleanup config upgrade"

    envs=$(ls "$HOME/.Python-Env" 2>/dev/null)

    if [[ $COMP_CWORD -eq 1 ]]; then
        # shellcheck disable=SC2207  # bash 3.2 (macOS) has no mapfile; splitting is intended
        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
        return
    fi

    case "$prev" in
        activate|remove|install|link)
            # shellcheck disable=SC2207  # bash 3.2 (macOS) has no mapfile; splitting is intended
            COMPREPLY=( $(compgen -W "$envs" -- "$cur") )
            ;;
    esac
}

complete -F _ikshvaku_complete ikshvaku
