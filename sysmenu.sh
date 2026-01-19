#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# === Interactive systemd service manager using fzf, gum, and bat ===

# Traps
trap 'echo "Error on line $LINENO: $BASH_COMMAND"; coredump' ERR
trap 'echo "Script interrupted"; exit 130' INT TERM

# Exit if run as root
if [[ $EUID -eq 0 ]]; then
    echo "This script must not be run as root"
    exit 1
fi

# Global config variables
FAVORITES_FILE="$HOME/.sysmenu_favorites"
SHOW_FAVORITES_ONLY=false
RUN_AS_APP=false

# Function to check if a command is available
require_command() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $1 is required but not installed"
        exit 1
    fi
}

# Commands required for this script
require_command fzf
require_command systemctl
require_command journalctl
require_command sudo
require_command awk

# Define the parameters used for this script
while [[ $# -gt 0 ]]; do
    case "$1" in
    --favorites | -f)
        SHOW_FAVORITES_ONLY=true
        shift
        ;;
    --app | -a)
        RUN_AS_APP=true
        shift
        ;;
    *)
        echo "Unknown parameter: $1"
        exit 1
        ;;
    esac
done

# Check if gum is installed
if command -v gum &>/dev/null; then
    IS_GUM_INSTALLED=true
else
    IS_GUM_INSTALLED=false
fi

# Check if bat is installed and define its command
if command -v bat &>/dev/null; then
    IS_BAT_INSTALLED=true
    BAT_COMMAND="bat"
elif command -v batcat &>/dev/null; then
    IS_BAT_INSTALLED=true
    BAT_COMMAND="batcat"
else
    IS_BAT_INSTALLED=false
fi

main() {
    # Function to get systemd units
    get_sysd_units() {
        # Define arguments for systemctl commands
        local args=(
            --all
            --plain
            --no-legend
            --no-pager
        )

        # List units with scope and format output
        list_units_with_scope() {
            local scope=$1

            systemctl --"$scope" list-units "${args[@]}" |
                awk -v scope="[$scope]" '{printf "%-60s %-15s %-10s %s\n", $1, $3, $4, scope}'
        }

        # List unit files with scope and format output
        list_unit_files_with_scope() {
            local scope=$1

            systemctl --"$scope" list-unit-files "${args[@]}" |
                awk -v scope="[$scope]" '{printf "%-60s %-15s %-10s %s\n", $1, $2, "(file)", scope}'
        }

        # List and sort units from both system and user scopes
        all_units=$(
            (
                list_units_with_scope system
                list_unit_files_with_scope system
                list_units_with_scope user
                list_unit_files_with_scope user
            ) | sort -u
        )

        # List favorite units from file if it exists
        if [[ -f $FAVORITES_FILE ]]; then
            # List favorite units
            favorite_units=$(printf "%s\n" "$all_units" |
                grep -Ff "$FAVORITES_FILE" |
                sed 's/^/★ /')

            # If showing only favorites, return only them
            if $SHOW_FAVORITES_ONLY; then
                printf "%s\n" "$favorite_units"
                return
            fi

            # List other units
            other_units=$(printf "%s\n" "$all_units" |
                grep -Fvf "$FAVORITES_FILE" |
                sed 's/^/  /')

            # Combine favorite and other units, emphasizing favorites
            printf "%s\n%s\n" "$favorite_units" "$other_units"
        else
            printf "%s\n" "$all_units"
        fi
    }

    # Use fuzzy-finder to select one or multiple systemd services and return to the variable
    selected=$(get_sysd_units |
        fzf --preview "echo {} | sed 's/^[★ ]* *//' | awk '{print \$1}' | xargs systemctl status --no-pager" \
            --preview-window=down:40%:wrap \
            --header 'Select a systemd service to manage' \
            --color "fg+:bold,hl:reverse,fg+:yellow,header:italic:underline" \
            --ansi \
            --multi \
            --border \
            --reverse)

    services=$(echo "$selected" | sed 's/^[★ ]* *//' | awk '{print $1}')
    scopes=$(echo "$selected" | sed 's/^[★ ]* *//' | awk '{print $NF}')

    [[ -z $services ]] && exit 0

    # Select an action to perform on the selected services using gum or fzf
    if $IS_GUM_INSTALLED; then
        action=$(
            printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs\ntoggle favorite" |
                gum choose --header "$(printf "%s\n" "Select action for:" "${services[*]}")"
        )
    else
        action=$(
            printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs\ntoggle favorite" |
                fzf --header "$(printf "%s\n" "Select action for:" "${services[*]}")" \
                    --border \
                    --reverse
        )
    fi

    [[ -z $action ]] && exit 0

    # Function to execute the selected action
    execute_action() {
        local services=$1
        local scopes=$2
        local action=$3

        # Run the selected action on the chosen services
        case $action in
        logs)
            # Show logs with bat or less
            local journalctl_args=()
            for service in $services; do
                journalctl_args+=(-u "$service")
            done

            if $IS_BAT_INSTALLED; then
                sudo journalctl "${journalctl_args[@]}" -xe | $BAT_COMMAND --paging=always -l log
            else
                sudo journalctl "${journalctl_args[@]}" -xe | less
            fi
            ;;
        toggle\ favorite)
            # Create favorites file if it doesn't exist
            if [[ ! -f $FAVORITES_FILE ]]; then
                touch "$FAVORITES_FILE"
                chmod 600 "$FAVORITES_FILE"
            fi

            # Add or remove services to/from favorites list
            for service in $services; do
                # Add service to favorites list
                if ! grep -qxF "$service" "$FAVORITES_FILE" 2>/dev/null; then
                    echo "$service" >>"$FAVORITES_FILE"
                else
                    # Remove service from favorites list if it exists
                    grep -vxF "$service" "$FAVORITES_FILE" >"${FAVORITES_FILE}.tmp" && mv "${FAVORITES_FILE}.tmp" "$FAVORITES_FILE"
                fi
            done
            ;;
        *)
            mapfile -t services_arr < <(printf "%s\n" "$services")
            mapfile -t scopes_arr < <(printf "%s\n" "$scopes")

            local -a system_services=()
            local -a user_services=()

            for i in "${!services_arr[@]}"; do
                local service=${services_arr[$i]}
                local scope=${scopes_arr[$i]}

                if [[ -z "$service" ]]; then
                    continue
                fi

                if [[ "$scope" == "[system]" ]]; then
                    system_services+=("$service")
                elif [[ "$scope" == "[user]" ]]; then
                    user_services+=("$service")
                fi
            done

            # Execute action on system services
            if ((${#system_services[@]} > 0)); then
                sudo systemctl --system --no-pager "$action" "${system_services[@]}"
            fi

            # Execute action on user services
            if ((${#user_services[@]} > 0)); then
                systemctl --user --no-pager "$action" "${user_services[@]}"
            fi

            # Display success message
            if $IS_GUM_INSTALLED; then
                gum style "Action successfully executed on:" "${services[*]}!" \
                    --foreground 212 \
                    --border double \
                    --margin "1 1" \
                    --padding "1 2" \
                    --align center \
                    --bold
            else
                echo "Action successfully executed on: ${services[*]}!"
            fi

            if $RUN_AS_APP; then
                read -rp "Press Enter to continue..."
                clear
            fi
            ;;
        esac
    }

    # Confirm the action with the user using gum or fzf
    if $IS_GUM_INSTALLED; then
        gum confirm "$(printf "%s\n" "Execute '$action' on" "${services[*]}"?)" || exit 0
        gum spin --spinner dot --title "$(printf "%s\n" "Running $action on" "${services[*]}...")" -- sleep 0.5

        execute_action "$services" "$scopes" "$action"
    else
        yesno=$(printf "yes\nno" |
            fzf --header "$(printf "%s\n" "Execute '$action' on" "${services[*]}"?)" \
                --border \
                --reverse \
                --disabled)

        [[ $yesno != "yes" ]] && exit 0

        execute_action "$services" "$scopes" "$action"
    fi
}

if $RUN_AS_APP; then
    while true; do
        main
    done
else
    main
fi
