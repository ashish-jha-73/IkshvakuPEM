# ~/.ikshvaku/ikshvaku.sh
# shellcheck shell=bash

IKSHVAKU_VERSION="1.2.0"
IKSHVAKU_UV_INSTALLER="https://astral.sh/uv/install.sh"
IKSHVAKU_ENV_DIR="${IKSHVAKU_ENV_DIR:-$HOME/.Python-Env}"
IKSHVAKU_HOME="${IKSHVAKU_HOME:-$HOME/.ikshvaku}"

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

# Source a venv activate script without letting `set -e` (the user's or the
# caller's) abort the shell on quirks inside the script. The user's errexit
# state is restored afterwards.
ikshvaku_source_activate() {
    local act="$1" __ik_had_e=0 __ik_rc=0
    case $- in *e*) __ik_had_e=1 ;; esac
    set +e
    # shellcheck disable=SC1090  # venv's activate script, path is dynamic by design
    . "$act"
    __ik_rc=$?
    [ "$__ik_had_e" -eq 1 ] && set -e
    return "$__ik_rc"
}

# Print the path to an environment's python interpreter.
ikshvaku_env_python() {
    local env_path="$1"
    if [ -f "$env_path/bin/python" ]; then
        printf '%s' "$env_path/bin/python"
    elif [ -f "$env_path/Scripts/python.exe" ]; then
        printf '%s' "$env_path/Scripts/python.exe"
    else
        return 1
    fi
}

# Create a seeded environment (shared by `create` and `init`).
ikshvaku_create_env() {
    local name="$1" pyver="$2"
    [ -z "$name" ] && { echo "Usage: ikshvaku create <env> [python-version]"; return 1; }
    [ -e "$IKSHVAKU_ENV_DIR/$name" ] && { echo "Environment '$name' already exists"; return 1; }
    ikshvaku_uv_install || return 1
    mkdir -p "$IKSHVAKU_ENV_DIR"
    if [ -z "$pyver" ]; then
        pyver=$(ikshvaku_config_get python_default)
    fi
    if [ -n "$pyver" ]; then
        uv venv --seed --python "$pyver" "$IKSHVAKU_ENV_DIR/$name" || return 1
    else
        uv venv --seed "$IKSHVAKU_ENV_DIR/$name" || return 1
    fi
    # --seed installs real pip; the shim below is only a fallback
    ikshvaku_pip_shim "$IKSHVAKU_ENV_DIR/$name"
    ikshvaku_touch_usage "$name"
    echo "Environment '$name' created"
}

# --- state: usage tracking & config ---

# Record last-used for an environment: "<epoch> <human date>" on one line.
# The epoch drives `cleanup`; the human date drives `list --size`.
ikshvaku_touch_usage() {
    mkdir -p "$IKSHVAKU_HOME/state/usage" 2>/dev/null || return 0
    printf '%s %s\n' "$(date +%s)" "$(date '+%Y-%m-%d %H:%M' 2>/dev/null)" \
        > "$IKSHVAKU_HOME/state/usage/$1" 2>/dev/null
    return 0
}

ikshvaku_usage_last_used() {
    local f="$IKSHVAKU_HOME/state/usage/$1"
    if [ -f "$f" ]; then
        awk '{ print $2 }' "$f" 2>/dev/null
    else
        printf 'never'
    fi
}

ikshvaku_config_get() {
    [ -f "$IKSHVAKU_HOME/config" ] || return 1
    awk -F= -v k="$1" '$1 == k { print $2; exit }' "$IKSHVAKU_HOME/config"
}

ikshvaku_config_set() {
    mkdir -p "$IKSHVAKU_HOME"
    {
        awk -F= -v k="$1" 'NF >= 2 && $1 != k' "$IKSHVAKU_HOME/config" 2>/dev/null
        printf '%s=%s\n' "$1" "$2"
    } > "$IKSHVAKU_HOME/config.tmp" && mv "$IKSHVAKU_HOME/config.tmp" "$IKSHVAKU_HOME/config"
}

# Is an environment linked to any project? (exact match on the env field)
ikshvaku_registry_env_linked() {
    [ -f "$IKSHVAKU_HOME/registry" ] || return 1
    awk -F'|' -v e="$1" '$2 == e { f=1; exit } END { exit (f ? 0 : 1) }' "$IKSHVAKU_HOME/registry"
}

# --- registry: project directory <-> environment links ---

ikshvaku_registry_get() {
    [ -f "$IKSHVAKU_HOME/registry" ] || return 1
    awk -F'|' -v d="$1" '$1 == d { print $2; exit }' "$IKSHVAKU_HOME/registry"
}

ikshvaku_registry_set() {
    mkdir -p "$IKSHVAKU_HOME"
    {
        awk -F'|' -v d="$1" 'NF >= 2 && $1 != d' "$IKSHVAKU_HOME/registry" 2>/dev/null
        printf '%s|%s\n' "$1" "$2"
    } > "$IKSHVAKU_HOME/registry.tmp" && mv "$IKSHVAKU_HOME/registry.tmp" "$IKSHVAKU_HOME/registry"
}

ikshvaku_registry_del() {
    [ -f "$IKSHVAKU_HOME/registry" ] || return 0
    awk -F'|' -v d="$1" 'NF >= 2 && $1 != d' "$IKSHVAKU_HOME/registry" \
        > "$IKSHVAKU_HOME/registry.tmp" \
        && mv "$IKSHVAKU_HOME/registry.tmp" "$IKSHVAKU_HOME/registry"
}

# Nearest linked env for a directory, walking up (git-style).
ikshvaku_auto_lookup() {
    local d="$1" r
    while :; do
        r=$(ikshvaku_registry_get "$d")
        [ -n "$r" ] && { printf '%s' "$r"; return 0; }
        [ "$d" = "/" ] && return 1
        d=$(dirname "$d")
    done
}

# Nearest registered project directory for a path, walking up.
ikshvaku_registry_dir() {
    local d="$1" e
    while :; do
        e=$(ikshvaku_registry_get "$d")
        [ -n "$e" ] && { printf '%s' "$d"; return 0; }
        [ "$d" = "/" ] && return 1
        d=$(dirname "$d")
    done
}

# --- auto-activation on cd (opt-in: ikshvaku auto on) ---

ikshvaku_auto_check() {
    [ -f "$IKSHVAKU_HOME/auto-on" ] || return 0
    # bash fires this on every prompt — only act when the directory changed
    if [ -z "${ZSH_VERSION:-}" ]; then
        [ "${_IKSHVAKU_LAST_DIR:-}" = "$PWD" ] && return 0
        _IKSHVAKU_LAST_DIR="$PWD"
    fi
    local target
    target=$(ikshvaku_auto_lookup "$PWD") || return 0
    [ -n "$target" ] || return 0
    [ "$target" = "${IKSHVAKU_ACTIVE:-}" ] && return 0
    [ -d "$IKSHVAKU_ENV_DIR/$target" ] || return 0
    [ -n "${IKSHVAKU_ACTIVE:-}" ] && deactivate >/dev/null 2>&1
    if ikshvaku activate "$target" >/dev/null 2>&1; then
        printf '\033[0;36m⚡ ikshvaku: %s activated\033[0m\n' "$target"
    fi
    return 0
}

ikshvaku_auto_install_hook() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        autoload -U add-zsh-hook 2>/dev/null
        add-zsh-hook chpwd ikshvaku_auto_check 2>/dev/null
    else
        case ";${PROMPT_COMMAND:-};" in
            *";ikshvaku_auto_check;"*) ;;
            *) PROMPT_COMMAND="ikshvaku_auto_check${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
        esac
    fi
}

# install the auto-activation hook on shell startup if it is enabled
if [ -f "$IKSHVAKU_HOME/auto-on" ]; then
    ikshvaku_auto_install_hook
fi

ikshvaku() {
    local ENV_DIR="$IKSHVAKU_ENV_DIR"

    case "$1" in
        list)
            if [ ! -d "$ENV_DIR" ] || [ -z "$(ls -A "$ENV_DIR" 2>/dev/null)" ]; then
                echo "No environments yet. Create one: ikshvaku create <env>"
                return 0
            fi
            if [ "$2" = "--size" ]; then
                local ld le lsz
                printf '%-18s %8s  %s\n' "ENV" "SIZE" "LAST USED"
                for ld in "$ENV_DIR"/*/; do
                    le=$(basename "$ld")
                    lsz=$(du -sh "$ld" 2>/dev/null | cut -f1)
                    printf '%-18s %8s  %s\n' "$le" "$lsz" "$(ikshvaku_usage_last_used "$le")"
                done
                echo ""
                echo "Envs total: $(du -sh "$ENV_DIR" 2>/dev/null | cut -f1)"
                if [ -d "$HOME/.cache/uv" ]; then
                    echo "uv cache:   $(du -sh "$HOME/.cache/uv" 2>/dev/null | cut -f1)  (prune with: ikshvaku cleanup --apply --cache)"
                fi
            else
                ls "$ENV_DIR"
            fi
            ;;

        create)
            [ -z "$2" ] && { echo "Usage: ikshvaku create <env> [python-version]"; return 1; }
            ikshvaku_create_env "$2" "$3" || return 1
            echo "Tip: activate it, then: pip install <package>"
            ;;

        init)
            local dir name
            dir=$(pwd -P)
            if [ "$dir" = "$HOME" ]; then
                echo "Refusing to link your home directory (it would match every subdirectory)"
                return 1
            fi
            if [ -n "$2" ]; then
                name="$2"
            else
                name=$(basename "$dir" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/^-*//; s/-*$//')
                [ -z "$name" ] && name="env"
            fi
            if [ ! -d "$ENV_DIR/$name" ]; then
                ikshvaku_create_env "$name" "$3" || return 1
            fi
            ikshvaku_registry_set "$dir" "$name"
            echo "Linked $dir -> '$name'"
            # bootstrap: install dependencies if the project ships a requirements.txt
            if [ -f "requirements.txt" ] && [ -d "$ENV_DIR/$name" ]; then
                if command -v uv >/dev/null 2>&1 || ikshvaku_uv_install; then
                    echo "Found requirements.txt — installing dependencies..."
                    uv pip install --python "$(ikshvaku_env_python "$ENV_DIR/$name")" -r requirements.txt \
                        || echo "⚠️  dependency installation failed — the env is still usable"
                fi
            fi
            [ -n "${IKSHVAKU_ACTIVE:-}" ] && [ "$IKSHVAKU_ACTIVE" != "$name" ] && deactivate >/dev/null 2>&1
            ikshvaku activate "$name" || echo "⚠️  could not auto-activate '$name' — run: ikshvaku activate $name"
            ;;

        link)
            [ -z "$2" ] && { echo "Usage: ikshvaku link <env>"; return 1; }
            [ ! -d "$ENV_DIR/$2" ] && { echo "Env not found: $2"; return 1; }
            ikshvaku_registry_set "$(pwd -P)" "$2"
            echo "Linked $(pwd -P) -> '$2'"
            ;;

        unlink)
            local cur linked
            cur=$(pwd -P)
            if [ -z "$(ikshvaku_registry_get "$cur")" ]; then
                # not linked here — remove the nearest parent's link (git-style)
                cur=$(ikshvaku_registry_dir "$cur") || {
                    echo "No linked environment found for this directory"
                    return 1
                }
            fi
            linked=$(ikshvaku_registry_get "$cur")
            ikshvaku_registry_del "$cur"
            echo "Unlinked $cur (was -> '$linked')"
            ;;

        links)
            if [ ! -s "$IKSHVAKU_HOME/registry" ]; then
                echo "No projects linked yet. Run: ikshvaku init"
                return 0
            fi
            local ld le
            while IFS='|' read -r ld le; do
                [ -z "$ld" ] && continue
                if [ -d "$ENV_DIR/$le" ]; then
                    printf '%s  ->  %s\n' "$ld" "$le"
                else
                    printf '%s  ->  %s  (missing env)\n' "$ld" "$le"
                fi
            done < "$IKSHVAKU_HOME/registry"
            ;;

        activate)
            local target env_act
            target="$2"
            if [ -z "$target" ]; then
                # bare activate: use this project's linked env (nearest parent)
                target=$(ikshvaku_auto_lookup "$(pwd -P)" || true)
                if [ -z "$target" ]; then
                    echo "No environment linked to this directory. Run: ikshvaku init"
                    return 1
                fi
            fi
            [ "$target" = "${IKSHVAKU_ACTIVE:-}" ] && { echo "Already in '$target'"; return 0; }
            [ ! -d "$ENV_DIR/$target" ] && { echo "Env not found: $target"; return 1; }
            env_act=$(ikshvaku_activate_script "$ENV_DIR/$target") || { echo "Env not found"; return 1; }
            ikshvaku_source_activate "$env_act" || echo "⚠️  activation of '$target' reported errors"
            export IKSHVAKU_ACTIVE="$target"
            ikshvaku_touch_usage "$target"
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
            local env_py env_act
            env_py=$(ikshvaku_env_python "$ENV_DIR/$env_name") || {
                echo "Env '$env_name' is missing its python"
                return 1
            }
            env_act=$(ikshvaku_activate_script "$ENV_DIR/$env_name") || {
                echo "Env '$env_name' is missing its activate script"
                return 1
            }
            # Run the install inside an isolated activate → install → deactivate
            # cycle (a subshell), so the current shell — and any env you have
            # active in it — is never disturbed.
            ikshvaku_touch_usage "$env_name"
            (
                ikshvaku_source_activate "$env_act" || true
                export IKSHVAKU_ACTIVE="$env_name"
                uv pip install --python "$env_py" "$@"
            )
            ;;

        run)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Usage: ikshvaku run <env> <command...>"
                return 1
            fi
            [ ! -d "$ENV_DIR/$2" ] && { echo "Env not found: $2"; return 1; }
            local run_env run_act run_rc
            run_env="$2"
            run_act=$(ikshvaku_activate_script "$ENV_DIR/$run_env") || {
                echo "Env '$run_env' is missing its activate script"
                return 1
            }
            shift 2
            ikshvaku_touch_usage "$run_env"
            (
                ikshvaku_source_activate "$run_act" || true
                "$@"
            )
            run_rc=$?
            return "$run_rc"
            ;;

        export)
            [ -z "$2" ] && { echo "Usage: ikshvaku export <env>  (> requirements.txt)"; return 1; }
            [ ! -d "$ENV_DIR/$2" ] && { echo "Env not found: $2"; return 1; }
            ikshvaku_uv_install || return 1
            ikshvaku_touch_usage "$2"
            uv pip freeze --python "$ENV_DIR/$2"
            ;;

        clone)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Usage: ikshvaku clone <src> <dst>"
                return 1
            fi
            [ ! -d "$ENV_DIR/$2" ] && { echo "Env not found: $2"; return 1; }
            [ -e "$ENV_DIR/$3" ] && { echo "Environment '$3' already exists"; return 1; }
            ikshvaku_uv_install || return 1
            local src_py tmpreqs
            src_py=$(ikshvaku_env_python "$ENV_DIR/$2") || {
                echo "Env '$2' is missing its python"
                return 1
            }
            uv venv --seed --python "$src_py" "$ENV_DIR/$3" || return 1
            ikshvaku_pip_shim "$ENV_DIR/$3"
            ikshvaku_touch_usage "$3"
            tmpreqs=$(mktemp)
            uv pip freeze --python "$ENV_DIR/$2" > "$tmpreqs" 2>/dev/null
            if [ -s "$tmpreqs" ]; then
                uv pip install --python "$ENV_DIR/$3" -r "$tmpreqs" \
                    || echo "⚠️  package install failed — '$3' created but incomplete"
            fi
            rm -f "$tmpreqs"
            echo "Cloned '$2' -> '$3'"
            ;;

        cleanup)
            local apply=0 do_cache=0 days
            days=$(ikshvaku_config_get cleanup_days || true)
            [ -z "$days" ] && days=90
            shift
            while [ $# -gt 0 ]; do
                case "$1" in
                    --apply) apply=1 ;;
                    --cache) do_cache=1 ;;
                    --days) days="$2"; shift ;;
                    *)
                        echo "Usage: ikshvaku cleanup [--days N] [--apply] [--cache]"
                        return 1
                        ;;
                esac
                shift
            done
            local now cutoff d e lastf last_epoch stamp total=0 stale=0
            now=$(date +%s)
            cutoff=$((now - days * 86400))
            echo "ikshvaku cleanup — stale = unused for $days days (linked projects and the active env are always kept)"
            echo ""
            for d in "$ENV_DIR"/*/; do
                [ -d "$d" ] || continue
                e=$(basename "$d")
                total=$((total + 1))
                if ikshvaku_registry_env_linked "$e"; then
                    printf '  keep      %-18s linked to a project\n' "$e"
                    continue
                fi
                if [ "$e" = "${IKSHVAKU_ACTIVE:-}" ]; then
                    printf '  keep      %-18s currently active\n' "$e"
                    continue
                fi
                lastf="$IKSHVAKU_HOME/state/usage/$e"
                if [ -f "$lastf" ]; then
                    last_epoch=$(awk '{ print $1 }' "$lastf" 2>/dev/null)
                    stamp=$(awk '{ print $2 }' "$lastf" 2>/dev/null)
                else
                    last_epoch=""
                    stamp="never"
                fi
                if [ -z "$last_epoch" ]; then
                    printf '  skip      %-18s no usage data (created before v1.2)\n' "$e"
                elif [ "$last_epoch" -le "$cutoff" ]; then
                    stale=$((stale + 1))
                    if [ "$apply" -eq 1 ]; then
                        rm -rf "${ENV_DIR:?}/$e"
                        rm -f "$IKSHVAKU_HOME/state/usage/$e"
                        printf '  DELETE    %-18s last used %s\n' "$e" "$stamp"
                    else
                        printf '  stale     %-18s last used %s\n' "$e" "$stamp"
                    fi
                else
                    printf '  keep      %-18s last used %s\n' "$e" "$stamp"
                fi
            done
            echo ""
            if [ "$stale" -eq 0 ]; then
                echo "Nothing to clean ($total environment(s) checked)."
            elif [ "$apply" -eq 1 ]; then
                echo "Deleted $stale environment(s)."
            else
                echo "Dry run: $stale environment(s) would be deleted. Re-run with --apply."
            fi
            if [ "$do_cache" -eq 1 ]; then
                if command -v uv >/dev/null 2>&1; then
                    uv cache prune
                else
                    echo "⚠️  uv not found — cannot prune the cache"
                fi
            fi
            ;;

        config)
            if [ -z "$2" ]; then
                if [ -f "$IKSHVAKU_HOME/config" ]; then
                    echo "# ~/.ikshvaku/config"
                    cat "$IKSHVAKU_HOME/config"
                else
                    echo "No configuration set."
                fi
                echo "Available keys: python_default, cleanup_days"
                return 0
            fi
            local cfgv
            if [ -z "$3" ]; then
                cfgv=$(ikshvaku_config_get "$2" || true)
                if [ -n "$cfgv" ]; then
                    echo "$2=$cfgv"
                else
                    echo "$2 is not set"
                fi
                return 0
            fi
            ikshvaku_config_set "$2" "$3"
            echo "Saved: $2=$3"
            ;;

        status)
            echo "ikshvaku $IKSHVAKU_VERSION"
            if [ -n "${IKSHVAKU_ACTIVE:-}" ]; then
                echo "Active env:   $IKSHVAKU_ACTIVE  ($ENV_DIR/$IKSHVAKU_ACTIVE)"
            else
                echo "Active env:   none"
            fi
            local here linked
            here=$(pwd -P)
            linked=$(ikshvaku_registry_get "$here" || true)
            if [ -n "$linked" ]; then
                echo "Linked:       this directory -> $linked"
            else
                linked=$(ikshvaku_auto_lookup "$here" || true)
                if [ -n "$linked" ]; then
                    echo "Linked:       parent directory -> $linked"
                else
                    echo "Linked:       none (run: ikshvaku init)"
                fi
            fi
            local show env_py count
            show="${IKSHVAKU_ACTIVE:-}"
            [ -z "$show" ] && show="$linked"
            if [ -n "$show" ] && [ -d "$ENV_DIR/$show" ]; then
                if env_py=$(ikshvaku_env_python "$ENV_DIR/$show"); then
                    echo "Python:       $("$env_py" --version 2>&1)"
                fi
                if command -v uv >/dev/null 2>&1; then
                    count=$(uv pip list --python "$ENV_DIR/$show" 2>/dev/null | awk 'NR>2' | wc -l | tr -d ' ')
                    echo "Packages:     ${count:-0}"
                else
                    echo "Packages:     ? (uv not found)"
                fi
                echo "Size:         $(du -sh "$ENV_DIR/$show" 2>/dev/null | cut -f1)"
            fi
            ;;

        doctor)
            local ok=1
            echo "ikshvaku $IKSHVAKU_VERSION — health check"
            echo ""
            if [ -f "$HOME/.ikshvaku/ikshvaku.sh" ]; then
                echo "✅ installation: ~/.ikshvaku present"
            else
                echo "❌ installation: ~/.ikshvaku not found — run the installer"
                ok=0
            fi
            if command -v uv >/dev/null 2>&1; then
                echo "✅ uv: $(uv --version 2>/dev/null) at $(command -v uv)"
            else
                echo "❌ uv: not found — it will be downloaded on the next create/install"
                ok=0
            fi
            local n
            if [ -d "$ENV_DIR" ]; then
                n=$(ls -A "$ENV_DIR" 2>/dev/null | wc -l | tr -d ' ')
                echo "✅ environments: $n in $ENV_DIR"
            else
                echo "ℹ️  environments: none yet"
            fi
            local rc blocks
            rc="$HOME/.bashrc"
            case "$(basename "${SHELL:-bash}")" in zsh) rc="$HOME/.zshrc" ;; esac
            blocks=$(grep -c ">>> Ikshvaku >>>" "$rc" 2>/dev/null || true)
            blocks=${blocks:-0}
            if [ "$blocks" -eq 1 ]; then
                echo "✅ shell integration: $rc"
            elif [ "$blocks" -eq 0 ]; then
                echo "⚠️  shell integration: not found in $rc — re-run the installer"
            else
                echo "❌ shell integration: $blocks blocks in $rc — run ikshvaku-uninstall, then reinstall"
                ok=0
            fi
            if [ -f "$IKSHVAKU_HOME/registry" ]; then
                local total=0 broken=0 rd re
                while IFS='|' read -r rd re; do
                    [ -z "$rd" ] && continue
                    total=$((total + 1))
                    if [ ! -d "$ENV_DIR/$re" ]; then
                        broken=$((broken + 1))
                        echo "⚠️  broken link: $rd -> '$re' (remove it: cd $rd && ikshvaku unlink)"
                    fi
                done < "$IKSHVAKU_HOME/registry"
                if [ "$broken" -eq 0 ]; then
                    echo "✅ registry: $total link(s), all valid"
                else
                    echo "❌ registry: $broken of $total link(s) broken"
                    ok=0
                fi
            else
                echo "ℹ️  registry: empty (no projects linked — try: ikshvaku init)"
            fi
            if [ -f "$IKSHVAKU_HOME/auto-on" ]; then
                echo "✅ auto-activation: ON (envs switch on cd)"
            else
                echo "ℹ️  auto-activation: off (enable with: ikshvaku auto on)"
            fi
            if [ -d "$HOME/.cache/uv" ]; then
                echo "ℹ️  uv cache: $(du -sh "$HOME/.cache/uv" 2>/dev/null | cut -f1) (prune with: uv cache prune)"
            fi
            echo ""
            if [ "$ok" -eq 1 ]; then
                echo "All checks passed."
            else
                echo "Some checks failed."
                return 1
            fi
            ;;

        auto)
            case "$2" in
                on)
                    mkdir -p "$IKSHVAKU_HOME"
                    touch "$IKSHVAKU_HOME/auto-on"
                    ikshvaku_auto_install_hook
                    echo "Auto-activation ON — cd into a linked project activates its env."
                    echo "(This session is hooked; other shells pick it up on restart.)"
                    ;;
                off)
                    rm -f "$IKSHVAKU_HOME/auto-on"
                    echo "Auto-activation OFF."
                    ;;
                *)
                    echo "Usage: ikshvaku auto on|off"
                    return 1
                    ;;
            esac
            ;;

        remove)
            [ -z "$2" ] && echo "Usage: ikshvaku remove <env>" && return 1
            [ ! -d "$ENV_DIR/$2" ] && echo "Env not found" && return 1
            rm -rf "${ENV_DIR:?}/$2"
            echo "Environment '$2' removed"
            ;;

        --version|version|-V)
            echo "ikshvaku $IKSHVAKU_VERSION"
            ;;

        *)
            echo "ikshvaku $IKSHVAKU_VERSION — Python environments powered by uv"
            echo ""
            echo "Commands:"
            echo "  ikshvaku list [--size]"
            echo "  ikshvaku status"
            echo "  ikshvaku doctor"
            echo "  ikshvaku create <env> [python-version]"
            echo "  ikshvaku init [env] [python-version]   link this directory to an env (+ requirements.txt)"
            echo "  ikshvaku link <env> / unlink"
            echo "  ikshvaku links"
            echo "  ikshvaku activate [env]                no arg = this project's env"
            echo "  ikshvaku deactivate"
            echo "  ikshvaku install <env> <pkg...>        or: ikshvaku install <pkg...> (active env)"
            echo "  ikshvaku run <env> <cmd...>            run a command inside an env"
            echo "  ikshvaku export <env>                  print installed packages (> requirements.txt)"
            echo "  ikshvaku clone <src> <dst>             duplicate an environment"
            echo "  ikshvaku cleanup [--days N] [--apply] [--cache]"
            echo "  ikshvaku config [key [value]]          python_default, cleanup_days"
            echo "  ikshvaku auto on|off                   switch envs automatically on cd"
            echo "  ikshvaku remove <env>"
            echo "  ikshvaku --version"
            echo ""
            echo "Powered by uv (downloaded automatically if missing)."
            echo "Environments ship with pip preinstalled (seeded by uv)."
            ;;
    esac
}
