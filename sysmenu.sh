#!/bin/bash

# Exit if fzf is not installed
if ! command -v fzf &>/dev/null; then
    echo "fzf is required but not installed. Please install fzf to use this script."
    exit 1
fi

# Check if gum is installed
IS_GUM_INSTALLED=false
if command -v gum &>/dev/null; then
    IS_GUM_INSTALLED=true
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
    (
        list_units_with_scope system
        list_unit_files_with_scope system
        list_units_with_scope user
        list_unit_files_with_scope user
    ) | sort -u
}

# Use fuzzy-finder to select a systemd service and return to the variable
service=$(get_sysd_units |
    fzf --preview 'systemctl status {1} --no-pager' \
        --preview-window=down:40%:wrap \
        --header 'Select a systemd service to manage' \
        --ansi \
        --border |
    awk '{print $1}')

[[ -z $service ]] && exit 0

# Select an action to perform on the selected service using gum or fzf
if $IS_GUM_INSTALLED; then
    action=$(printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs" |
        gum choose --header "Select action for $service")
else
    action=$(printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs" |
        fzf --header "Select action for $service" --border)
fi

[[ -z $action ]] && exit 0

execute_action() {
    local service=$1
    local action=$2

    # Run the selected action on the chosen service
    if [[ $action == "logs" ]]; then
        sudo journalctl -u "$service" -xe | less
    else
        sudo systemctl "$action" "$service"
    fi
}

# Confirm the action with the user using gum or fzf
if $IS_GUM_INSTALLED; then
    gum confirm "Execute '$action' on '$service'?" || exit 0
    gum spin --spinner dot --title "Running $action on $service..." -- sleep 1
    execute_action "$service" "$action"
else
    yesno=$(printf "yes\nno" |
        fzf --header "Execute '$action' on '$service'?" --border)
    [[ $yesno != "yes" ]] && exit 0
    echo "Running $action on $service..."
    execute_action "$service" "$action"
fi
