# ~/.ikshvaku/ikshvaku.fish — Ikshvaku for Fish.
# Sourced from ~/.config/fish/config.fish by the installer.

set -g IKSHVAKU_VERSION "1.4.0"
set -g IKSHVAKU_ENV_DIR "$HOME/.Python-Env"
set -g IKSHVAKU_HOME "$HOME/.ikshvaku"

function __ikshvaku_uv_install --description "Download uv if it is not installed"
    if command -q uv
        return 0
    end
    echo ":: uv not found - downloading uv..."
    if command -q curl
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else if command -q wget
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "curl or wget is required to download uv"
        return 1
    end
    if status is-stdin 2>/dev/null
        : # no-op, keeps fish happy on old versions
    end
    if test -d $HOME/.local/bin
        fish_add_path -g $HOME/.local/bin 2>/dev/null; or set -gx PATH $HOME/.local/bin $PATH
    end
    if test -d $HOME/.cargo/bin
        fish_add_path -g $HOME/.cargo/bin 2>/dev/null; or set -gx PATH $HOME/.cargo/bin $PATH
    end
    if not command -q uv
        echo "uv installation failed - see https://docs.astral.sh/uv/"
        return 1
    end
    echo ":: uv ready"
    return 0
end

function __ikshvaku_touch_usage --argument-names env_name
    mkdir -p "$IKSHVAKU_HOME/state/usage" 2>/dev/null
    printf '%s %s\n' (date +%s) (date '+%Y-%m-%d %H:%M') > "$IKSHVAKU_HOME/state/usage/$env_name" 2>/dev/null
    return 0
end

function __ikshvaku_usage_last_used --argument-names env_name
    set -l f "$IKSHVAKU_HOME/state/usage/$env_name"
    if test -f "$f"
        set -l line (head -n1 "$f" 2>/dev/null)
        if test (count $line) -ge 2
            echo "$line[2]"
            return 0
        end
    end
    echo never
end

function __ikshvaku_config_get --argument-names key
    if test -f "$IKSHVAKU_HOME/config"
        while read -l line
            set -l parts (string split '=' -- "$line")
            if test (count $parts) -ge 2; and test "$parts[1]" = "$key"
                echo "$parts[2]"
                return 0
            end
        end < "$IKSHVAKU_HOME/config"
    end
    return 1
end

function __ikshvaku_config_set --argument-names key value
    mkdir -p "$IKSHVAKU_HOME"
    set -l kept
    if test -f "$IKSHVAKU_HOME/config"
        while read -l line
            set -l parts (string split '=' -- "$line")
            if test (count $parts) -ge 2; and test "$parts[1]" != "$key"
                set -a kept "$line"
            end
        end < "$IKSHVAKU_HOME/config"
    end
    set -a kept "$key=$value"
    printf '%s\n' $kept > "$IKSHVAKU_HOME/config"
end

function __ikshvaku_config_del --argument-names key
    if not test -f "$IKSHVAKU_HOME/config"
        return 0
    end
    set -l kept
    while read -l line
        set -l parts (string split '=' -- "$line")
        if test (count $parts) -ge 2; and test "$parts[1]" != "$key"
            set -a kept "$line"
        end
    end < "$IKSHVAKU_HOME/config"
    printf '%s\n' $kept > "$IKSHVAKU_HOME/config"
end

function __ikshvaku_registry_get --argument-names dir
    if not test -f "$IKSHVAKU_HOME/registry"
        return 1
    end
    while read -l line
        set -l parts (string split '|' -- "$line")
        if test (count $parts) -ge 2; and test "$parts[1]" = "$dir"
            echo "$parts[2]"
            return 0
        end
    end < "$IKSHVAKU_HOME/registry"
    return 1
end

function __ikshvaku_registry_set --argument-names dir env_name
    mkdir -p "$IKSHVAKU_HOME"
    set -l kept
    if test -f "$IKSHVAKU_HOME/registry"
        while read -l line
            set -l parts (string split '|' -- "$line")
            if test (count $parts) -ge 2; and test "$parts[1]" != "$dir"
                set -a kept "$line"
            end
        end < "$IKSHVAKU_HOME/registry"
    end
    set -a kept "$dir|$env_name"
    printf '%s\n' $kept > "$IKSHVAKU_HOME/registry"
end

function __ikshvaku_registry_del --argument-names dir
    if not test -f "$IKSHVAKU_HOME/registry"
        return 0
    end
    set -l kept
    while read -l line
        set -l parts (string split '|' -- "$line")
        if test (count $parts) -ge 2; and test "$parts[1]" != "$dir"
            set -a kept "$line"
        end
    end < "$IKSHVAKU_HOME/registry"
    printf '%s\n' $kept > "$IKSHVAKU_HOME/registry"
end

function __ikshvaku_registry_env_linked --argument-names env_name
    if not test -f "$IKSHVAKU_HOME/registry"
        return 1
    end
    while read -l line
        set -l parts (string split '|' -- "$line")
        if test (count $parts) -ge 2; and test "$parts[2]" = "$env_name"
            return 0
        end
    end < "$IKSHVAKU_HOME/registry"
    return 1
end

function __ikshvaku_auto_lookup --argument-names dir
    set -l d "$dir"
    while true
        set -l e (__ikshvaku_registry_get "$d")
        if test -n "$e"
            echo "$e"
            return 0
        end
        if test "$d" = "/"
            return 1
        end
        set d (dirname "$d")
    end
end

function __ikshvaku_activate_script --argument-names env_path
    if test -f "$env_path/bin/activate.fish"
        echo "$env_path/bin/activate.fish"
        return 0
    end
    return 1
end

function __ikshvaku_env_python --argument-names env_path
    if test -f "$env_path/bin/python"
        echo "$env_path/bin/python"
        return 0
    end
    return 1
end

function __ikshvaku_auto_check --on-variable PWD --description "Ikshvaku auto-activation on directory change"
    if not test -f "$IKSHVAKU_HOME/auto-on"
        return 0
    end
    set -l target (__ikshvaku_auto_lookup "$PWD")
    if test -z "$target"
        return 0
    end
    if test "$target" = "$IKSHVAKU_ACTIVE"
        return 0
    end
    if not test -d "$IKSHVAKU_ENV_DIR/$target"
        return 0
    end
    if set -q IKSHVAKU_ACTIVE
        deactivate >/dev/null 2>&1
    end
    if ikshvaku activate "$target" >/dev/null 2>&1
        echo (set_color cyan)"⚡ ikshvaku: $target activated"(set_color normal)
    end
    return 0
end

if test -f "$IKSHVAKU_HOME/auto-on"
    echo (set_color yellow)"ikshvaku: auto-activation is ON - restart this shell to hook cd events."(set_color normal)
end

function ikshvaku --description "Ikshvaku Python environment manager (powered by uv)"
    set -l cmd ""
    if test (count $argv) -ge 1
        set cmd $argv[1]
    end
    switch "$cmd"
        case list
            if not test -d "$IKSHVAKU_ENV_DIR"; or test (count (ls -A "$IKSHVAKU_ENV_DIR" 2>/dev/null)) -eq 0
                echo "No environments yet. Create one: ikshvaku create <env>"
                return 0
            end
            ls "$IKSHVAKU_ENV_DIR"
        case create
            if test (count $argv) -lt 2
                echo "Usage: ikshvaku create <env> [python-version]"
                return 1
            end
            if test -e "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Environment '$argv[2]' already exists"
                return 1
            end
            if not __ikshvaku_uv_install
                return 1
            end
            mkdir -p "$IKSHVAKU_ENV_DIR"
            set -l pyargs venv --seed
            if test (count $argv) -ge 3
                set -a pyargs --python $argv[3]
            end
            set -a pyargs "$IKSHVAKU_ENV_DIR/$argv[2]"
            uv $pyargs
            or return 1
            __ikshvaku_touch_usage "$argv[2]"
            echo "Environment '$argv[2]' created"
            echo "Tip: activate it, then: pip install <package>"
        case init
            if test (count $argv) -lt 2
                echo "Usage: ikshvaku init <env> [python-version]"
                echo "(fish auto-naming is not supported — pass an environment name)"
                return 1
            end
            set -l dir (pwd)
            if test "$dir" = "$HOME"
                echo "Refusing to link your home directory"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                ikshvaku create $argv[2..-1]
                or return 1
            end
            __ikshvaku_registry_set "$dir" "$argv[2]"
            echo "Linked $dir -> '$argv[2]'"
            if set -q IKSHVAKU_ACTIVE; and test "$IKSHVAKU_ACTIVE" != "$argv[2]"
                deactivate >/dev/null 2>&1
            end
            ikshvaku activate "$argv[2]"
        case link
            if test (count $argv) -lt 2
                echo "Usage: ikshvaku link <env>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found: $argv[2]"
                return 1
            end
            set -l cur (pwd)
            __ikshvaku_registry_set "$cur" "$argv[2]"
            echo "Linked $cur -> '$argv[2]'"
        case unlink
            if test -z (__ikshvaku_registry_get (pwd))
                echo "This directory has no linked environment"
                return 1
            end
            set -l cur (pwd)
            __ikshvaku_registry_del "$cur"
            echo "Unlinked $cur"
        case links
            if not test -f "$IKSHVAKU_HOME/registry"
                echo "No projects linked yet. Run: ikshvaku init"
                return 0
            end
            while read -l line
                set -l parts (string split '|' -- "$line")
                if test (count $parts) -ge 2
                    echo "$parts[1]  ->  $parts[2]"
                end
            end < "$IKSHVAKU_HOME/registry"
        case activate
            set -l target
            if test (count $argv) -ge 2
                set target $argv[2]
            else
                set target (__ikshvaku_auto_lookup (pwd))
                if test -z "$target"
                    echo "No environment linked to this directory. Run: ikshvaku init"
                    return 1
                end
            end
            if test "$target" = "$IKSHVAKU_ACTIVE"
                echo "Already in '$target'"
                return 0
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$target"
                echo "Env not found: $target"
                return 1
            end
            set -l act (__ikshvaku_activate_script "$IKSHVAKU_ENV_DIR/$target")
            if test -z "$act"
                echo "Env not found"
                return 1
            end
            source "$act"
            set -gx IKSHVAKU_ACTIVE "$target"
            __ikshvaku_touch_usage "$target"
        case deactivate
            if functions -q deactivate
                deactivate
            else
                echo "No env active"
            end
            set -e IKSHVAKU_ACTIVE
        case install
            if test (count $argv) -lt 3
                echo "Usage: ikshvaku install <env> <pkg...>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found: $argv[2]"
                return 1
            end
            if not __ikshvaku_uv_install
                return 1
            end
            set -l env_name $argv[2]
            set -l pkgs $argv[3..-1]
            __ikshvaku_touch_usage "$env_name"
            uv pip install --python "$IKSHVAKU_ENV_DIR/$env_name/bin/python" $pkgs
        case run
            if test (count $argv) -lt 3
                echo "Usage: ikshvaku run <env> <cmd...>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found: $argv[2]"
                return 1
            end
            set -l act (__ikshvaku_activate_script "$IKSHVAKU_ENV_DIR/$argv[2]")
            if test -z "$act"
                echo "Env '$argv[2]' is missing its activate script"
                return 1
            end
            set -l cmd_args $argv[3..-1]
            __ikshvaku_touch_usage "$argv[2]"
            source "$act"
            set -l exe $cmd_args[1]
            set -l rest $cmd_args[2..-1]
            $exe $rest
            set -l rc $status
            deactivate >/dev/null 2>&1
            return $rc
        case export
            if test (count $argv) -lt 2
                echo "Usage: ikshvaku export <env>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found: $argv[2]"
                return 1
            end
            if not __ikshvaku_uv_install
                return 1
            end
            __ikshvaku_touch_usage "$argv[2]"
            uv pip freeze --python "$IKSHVAKU_ENV_DIR/$argv[2]"
        case clone
            if test (count $argv) -lt 3
                echo "Usage: ikshvaku clone <src> <dst>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found: $argv[2]"
                return 1
            end
            if not __ikshvaku_uv_install
                return 1
            end
            set -l src_py (__ikshvaku_env_python "$IKSHVAKU_ENV_DIR/$argv[2]")
            uv venv --seed --python "$src_py" "$IKSHVAKU_ENV_DIR/$argv[3]"
            or return 1
            __ikshvaku_touch_usage "$argv[3]"
            set -l tmpf (mktemp)
            uv pip freeze --python "$IKSHVAKU_ENV_DIR/$argv[2]" > "$tmpf" 2>/dev/null
            if test -s "$tmpf"
                uv pip install --python "$IKSHVAKU_ENV_DIR/$argv[3]/bin/python" -r "$tmpf"
            end
            rm -f "$tmpf"
            echo "Cloned '$argv[2]' -> '$argv[3]'"
        case status
            echo "ikshvaku $IKSHVAKU_VERSION"
            if set -q IKSHVAKU_ACTIVE
                echo "Active env:   $IKSHVAKU_ACTIVE  ($IKSHVAKU_ENV_DIR/$IKSHVAKU_ACTIVE)"
            else
                echo "Active env:   none"
            end
            set -l linked (__ikshvaku_registry_get (pwd))
            if test -n "$linked"
                echo "Linked:       this directory -> $linked"
            else
                set linked (__ikshvaku_auto_lookup (pwd))
                if test -n "$linked"
                    echo "Linked:       parent directory -> $linked"
                else
                    echo "Linked:       none (run: ikshvaku init <env>)"
                end
            end
        case doctor
            echo "ikshvaku $IKSHVAKU_VERSION - health check"
            if test -f "$HOME/.ikshvaku/ikshvaku.fish"
                echo "[OK] installation: ~/.ikshvaku present"
            else
                echo "[X] installation: ~/.ikshvaku not found - run the installer"
            end
            if command -q uv
                echo "[OK] uv: "(uv --version 2>/dev/null)" at "(command -v uv)
            else
                echo "[X] uv: not found"
            end
            if test -f "$IKSHVAKU_HOME/auto-on"
                echo "[OK] auto-activation: ON"
            else
                echo "[i]  auto-activation: off (enable with: ikshvaku auto on)"
            end
        case auto
            switch "$argv[2]"
                case on
                    mkdir -p "$IKSHVAKU_HOME"
                    touch "$IKSHVAKU_HOME/auto-on"
                    echo "Auto-activation ON - cd into a linked project activates its env."
                    echo "(Restart your shell to hook new sessions.)"
                case off
                    rm -f "$IKSHVAKU_HOME/auto-on"
                    echo "Auto-activation OFF."
                case '*'
                    echo "Usage: ikshvaku auto on|off"
            end
        case remove
            if test (count $argv) -lt 2
                echo "Usage: ikshvaku remove <env>"
                return 1
            end
            if not test -d "$IKSHVAKU_ENV_DIR/$argv[2]"
                echo "Env not found"
                return 1
            end
            rm -rf "$IKSHVAKU_ENV_DIR/$argv[2]"
            echo "Environment '$argv[2]' removed"
        case version
            echo "ikshvaku $IKSHVAKU_VERSION"
        case '--version' '-V'
            echo "ikshvaku $IKSHVAKU_VERSION"
        case upgrade
            echo "ikshvaku $IKSHVAKU_VERSION - upgrading to the latest release..."
            curl -LsSf "https://raw.githubusercontent.com/ashish-jha-73/IkshvakuPEM/main/install.sh?cb="(date +%s) | bash
            echo "Restart your shell to load the new version."
        case cleanup
            echo "cleanup is available in the bash/PowerShell integration."
            echo "Fish users: run it from a bash shell, or remove envs with: ikshvaku remove <env>"
        case config
            echo "config is available in the bash/PowerShell integration."
            echo "Fish users: edit ~/.ikshvaku/config directly (python_default=..., cleanup_days=...)"
        case jupyter
            echo "jupyter is available in the bash/PowerShell integration."
        case prompt
            if set -q IKSHVAKU_ACTIVE
                printf '(%s) ' "$IKSHVAKU_ACTIVE"
            end
        case '*'
            echo "ikshvaku $IKSHVAKU_VERSION - Python environments powered by uv (fish)"
            echo ""
            echo "Commands:"
            echo "  ikshvaku list"
            echo "  ikshvaku status"
            echo "  ikshvaku doctor"
            echo "  ikshvaku create <env> [python-version]"
            echo "  ikshvaku init <env> [python-version]   link this directory to an env"
            echo "  ikshvaku link <env> / unlink"
            echo "  ikshvaku links"
            echo "  ikshvaku activate [env]                no arg = this project's env"
            echo "  ikshvaku deactivate"
            echo "  ikshvaku install <env> <pkg...>"
            echo "  ikshvaku run <env> <cmd...>"
            echo "  ikshvaku export <env>"
            echo "  ikshvaku clone <src> <dst>"
            echo "  ikshvaku auto on|off"
            echo "  ikshvaku remove <env>"
            echo "  ikshvaku --version"
            echo ""
            echo "Powered by uv (downloaded automatically if missing)."
            echo "Environments ship with pip preinstalled (seeded by uv)."
    end
end

# fish tab completion
complete -c ikshvaku -f
complete -c ikshvaku -n '__fish_use_subcommand' -a 'list create activate deactivate install remove init link unlink links status doctor auto run export clone cleanup config upgrade help version'
complete -c ikshvaku -n '__fish_seen_subcommand_from activate remove install link' -a '(__ikshvaku_registry_envs 2>/dev/null)'
function __ikshvaku_registry_envs --description "list environment names for completion"
    if test -f "$IKSHVAKU_HOME/registry"
        while read -l line
            set -l parts (string split '|' -- "$line")
            if test (count $parts) -ge 2
                echo "$parts[2]"
            end
        end < "$IKSHVAKU_HOME/registry"
    end
    ls "$IKSHVAKU_ENV_DIR" 2>/dev/null
end
