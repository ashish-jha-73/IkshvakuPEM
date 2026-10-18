# ~/.ikshvaku/ikshvaku.sh
# shellcheck shell=bash

IKSHVAKU_UV_INSTALLER="https://astral.sh/uv/install.sh"

# Download and install uv if it is not already available.
ikshvaku_uv_install() {
    command -v uv >/dev/null 2>&1 && return 0

    printf "\033[0;33m:: uv not found — downloading uv...\033[0m\n"
    if command -v curl >/dev/null 2>&1; then
        curl -LsSf "$IKSHVAKU_UV_INSTALLER" | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$IKSHVAKU_UV_INSTALLER" | sh
    else
        printf "\033[0;31m:: curl or wget is required to download uv\033[0m\n"
        return 1
    fi

    # The installer drops the binary in ~/.local/bin (older versions: ~/.cargo/bin)
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    if ! command -v uv >/dev/null 2>&1; then
        printf "\033[0;31m:: uv installation failed — see https://docs.astral.sh/uv/\033[0m\n"
        return 1
    fi

    printf "\033[0;32m:: uv ready\033[0m\n"
}

# Drop a tiny `pip` shim into a new environment that forwards to `uv pip`.
# Classic `pip install ...` keeps working inside the env, without bundling
# ~6MB of real pip per environment.
ikshvaku_pip_shim() {
    local env_path="$1"
    local pip_dir="$env_path/bin"
    local python_bin="$env_path/bin/python"

    # Windows (Git Bash) venvs use Scripts/ instead of bin/
    if [ ! -d "$pip_dir" ] && [ -d "$env_path/Scripts" ]; then
        pip_dir="$env_path/Scripts"
        python_bin="$env_path/Scripts/python.exe"
    fi

    [ -d "$pip_dir" ] || return 1
    # real pip already present (uv --seed) — nothing to do
    [ -f "$pip_dir/pip" ] && return 0

    cat > "$pip_dir/pip" <<EOF
#!/bin/sh
# Ikshvaku: uv-backed pip shim — forwards to 'uv pip' against this environment
case "\$1" in
    --version|-V)
        echo "pip (ikshvaku uv-shim) on \$(uv --version 2>/dev/null || echo uv)"
        exit 0
        ;;
esac
[ \$# -eq 0 ] && exec uv pip --python "$python_bin"
__ik_cmd="\$1"; shift
exec uv pip "\$__ik_cmd" --python "$python_bin" "\$@"
EOF
    chmod +x "$pip_dir/pip"
}

# Print the path to an environment's activate script (bin/ on Unix,
# Scripts/ on Windows), or fail if the env has none.
ikshvaku_activate_script() {
    local env_path="$1"
    if [ -f "$env_path/bin/activate" ]; then
        printf '%s' "$env_path/bin/activate"
    elif [ -f "$env_path/Scripts/activate" ]; then
        printf '%s' "$env_path/Scripts/activate"
    else
        return 1
    fi
}

ikshvaku() {
    local ENV_DIR="$HOME/.Python-Env"

    case "$1" in
        list)
            if [ ! -d "$ENV_DIR" ] || [ -z "$(ls -A "$ENV_DIR" 2>/dev/null)" ]; then
                echo "No environments yet. Create one: ikshvaku create <env>"
                return 0
            fi
            ls "$ENV_DIR"
            ;;

        create)
            [ -z "$2" ] && echo "Usage: ikshvaku create <env> [python-version]" && return 1
            [ -e "$ENV_DIR/$2" ] && echo "Environment '$2' already exists" && return 1
            ikshvaku_uv_install || return 1
            mkdir -p "$ENV_DIR"
            if [ -n "$3" ]; then
                uv venv --seed --python "$3" "$ENV_DIR/$2" || return 1
            else
                uv venv --seed "$ENV_DIR/$2" || return 1
            fi
            # --seed installs real pip; the shim below is only a fallback
            # for environments that somehow end up without one
            ikshvaku_pip_shim "$ENV_DIR/$2"
            echo "Environment '$2' created"
            echo "Tip: activate it, then: pip install <package>"
            ;;

        activate)
            [ -z "$2" ] && echo "Usage: ikshvaku activate <env>" && return 1
            local env_act
            env_act=$(ikshvaku_activate_script "$ENV_DIR/$2") || { echo "Env not found"; return 1; }
            # shellcheck disable=SC1090  # venv's activate script, path is dynamic by design
            source "$env_act"
            export IKSHVAKU_ACTIVE="$2"
            ;;

        deactivate)
            deactivate 2>/dev/null || echo "No env active"
            unset IKSHVAKU_ACTIVE
            ;;

        install)
            if [ -z "$2" ]; then
                echo "Usage: ikshvaku install <env> <package...>"
                echo "       or, while an env is active: ikshvaku install <package...>"
                return 1
            fi
            local env_name
            if [ -d "$ENV_DIR/$2" ]; then
                # explicit form: ikshvaku install <env> <package...>
                if [ -z "$3" ]; then
                    echo "Usage: ikshvaku install $2 <package...>"
                    return 1
                fi
                env_name="$2"
                shift 2
            elif [ -n "$IKSHVAKU_ACTIVE" ] && [ -d "$ENV_DIR/$IKSHVAKU_ACTIVE" ]; then
                # active form: every argument is a package for the active env
                env_name="$IKSHVAKU_ACTIVE"
                shift 1
            else
                echo "Env not found: $2"
                echo "Usage: ikshvaku install <env> <package...>"
                return 1
            fi
            ikshvaku_uv_install || return 1
            # Windows venvs put python in Scripts/python.exe instead of bin/python
            local env_bin env_act
            if [ -f "$ENV_DIR/$env_name/bin/python" ]; then
                env_bin="$ENV_DIR/$env_name/bin/python"
            else
                env_bin="$ENV_DIR/$env_name/Scripts/python.exe"
            fi
            env_act=$(ikshvaku_activate_script "$ENV_DIR/$env_name") || {
                echo "Env '$env_name' is missing its activate script"
                return 1
            }
            # Run the install inside an isolated activate → install → deactivate
            # cycle (a subshell), so the current shell — and any env you have
            # active in it — is never disturbed.
            (
                # shellcheck disable=SC1090  # venv's activate script, path is dynamic by design
                source "$env_act"
                export IKSHVAKU_ACTIVE="$env_name"
                uv pip install --python "$env_bin" "$@"
            )
            ;;

        remove)
            [ -z "$2" ] && echo "Usage: ikshvaku remove <env>" && return 1
            [ ! -d "$ENV_DIR/$2" ] && echo "Env not found" && return 1
            rm -rf "${ENV_DIR:?}/$2"
            echo "Environment '$2' removed"
            ;;

        *)
            echo "Commands:"
            echo "  ikshvaku list"
            echo "  ikshvaku create <env> [python-version]"
            echo "  ikshvaku activate <env>"
            echo "  ikshvaku deactivate"
            echo "  ikshvaku install <env> <package...>   (or: ikshvaku install <package...> while active)"
            echo "  ikshvaku remove <env>"
            echo ""
            echo "Powered by uv (downloaded automatically if missing)."
            echo "Environments ship with pip preinstalled (seeded by uv)."
            ;;
    esac
}
