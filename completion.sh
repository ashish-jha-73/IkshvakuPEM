# ~/.ikshvaku/completion.sh

_ikshvaku_complete() {
    local cur prev cmds envs

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    cmds="list create activate deactivate install remove"

    envs=$(ls "$HOME/.Python-Env" 2>/dev/null)

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
        return
    fi

    case "$prev" in
        activate|remove|install)
            COMPREPLY=( $(compgen -W "$envs" -- "$cur") )
            ;;
    esac
}

complete -F _ikshvaku_complete ikshvaku
