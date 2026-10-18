#compdef ikshvaku
# Native zsh completion for Ikshvaku (installed by install.sh for zsh users).

_ikshvaku() {
    local -a cmds
    local -a envs
    cmds=(
        'list:list environments'
        'list --size:environments with disk usage'
        'status:active env, project link, python, packages, size'
        'doctor:health check'
        'create:create a new environment'
        'init:link the current directory to an environment'
        'link:link this directory to an environment'
        'unlink:remove the link for this directory'
        'links:show all project links'
        'activate:activate an environment'
        'deactivate:deactivate the active environment'
        'install:install packages into an environment'
        'run:run a command inside an environment'
        'export:print installed packages'
        'clone:duplicate an environment'
        'cleanup:remove stale environments'
        'config:configure defaults'
        'jupyter:register env as a Jupyter kernel'
        'prompt:print a prompt prefix for PS1'
        'auto:toggle auto-activation on cd'
        'remove:delete an environment'
        'upgrade:update Ikshvaku'
        'help:detailed help for a command'
    )
    if [[ -d "$HOME/.Python-Env" ]]; then
        envs=("$HOME/.Python-Env"/*(N:t))
    fi

    if (( CURRENT == 2 )); then
        _describe -t commands 'ikshvaku command' cmds
    elif (( CURRENT >= 3 )); then
        local cmdname="${words[2]}"
        case "$cmdname" in
            activate|remove|install|link|run|export|clone|jupyter)
                _describe -t environments 'environment' envs
                ;;
            auto)
                _values 'state' on off
                ;;
            list)
                _values 'option' --size --json
                ;;
            status|links)
                _values 'option' --json
                ;;
            config)
                _values 'key' python_default cleanup_days
                ;;
        esac
    fi
}

_ikshvaku "$@"
