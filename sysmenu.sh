#!/bin/bash

# Interactive systemd service manager using fzf, gum, and bat

# Global config variables
FAVORITES_FILE="$HOME/.sysmenu_favorites"
SHOW_FAVORITES_ONLY=false

# Exit if fzf is not installed
if ! command -v fzf &>/dev/null; then
    echo "fzf is required but not installed. Please install fzf to use this script."
    exit 1
fi

# Define the parameters used for this script
while [[ $# -gt 0 ]]; do
    case "$1" in
    --favorites | -f)
        SHOW_FAVORITES_ONLY=true
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

# Use fuzzy-finder to select a systemd service and return to the variable
service=$(get_sysd_units |
    fzf --preview 'systemctl status {1} --no-pager' \
        --preview-window=down:40%:wrap \
        --header 'Select a systemd service to manage' \
        --color "fg+:bold,hl:reverse,fg+:yellow,header:italic:underline" \
        --ansi \
        --border \
        --reverse |
    sed 's/^[★ ]* *//' |
    awk '{print $1}')

[[ -z $service ]] && exit 0

# Select an action to perform on the selected service using gum or fzf
if $IS_GUM_INSTALLED; then
    action=$(printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs\nadd to favorites" |
        gum choose --header "Select action for $service")
else
    action=$(
        printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs\nadd to favorites" |
            fzf --header "Select action for $service" \
                --border \
                --reverse
    )
fi

[[ -z $action ]] && exit 0

execute_action() {
    local service=$1
    local action=$2

    # Run the selected action on the chosen service
    if [[ $action == "logs" ]]; then
        # Show logs with bat or less
        if $IS_BAT_INSTALLED; then
            sudo journalctl -u "$service" -xe | $BAT_COMMAND --paging=always -l log
        else
            sudo journalctl -u "$service" -xe | less
        fi
    elif [[ $action == "add to favorites" ]]; then
        # Create favorites file if it doesn't exist
        if [[ ! -f $FAVORITES_FILE ]]; then
            touch "$FAVORITES_FILE"
        fi

        # Add service to favorites list
        echo "$service" >>"$FAVORITES_FILE"
    else
        sudo systemctl "$action" "$service"
    fi
}

# Confirm the action with the user using gum or fzf
if $IS_GUM_INSTALLED; then
    gum confirm "Execute '$action' on '$service'?" || exit 0
    gum spin --spinner dot --title "Running $action on $service..." -- sleep 0.5

    execute_action "$service" "$action"
else
    yesno=$(printf "yes\nno" |
        fzf --header "Execute '$action' on '$service'?" \
            --border \
            --reverse \
            --disabled)

    [[ $yesno != "yes" ]] && exit 0

    execute_action "$service" "$action"
fi
