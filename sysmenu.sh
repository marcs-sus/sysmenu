#!/bin/bash

get_sysd_units() {
    # Define arguments for systemctl commands
    local args=(
        --all
        --plain
        --no-legend
        --no-pager
    )

    # List systemd units and unit files for a given scope
    list_units_with_scope() {
        local scope=$1

        # Shift parameter to get remaining args
        shift
        (
            systemctl --"$scope" list-units "${args[@]}"
            systemctl --"$scope" list-unit-files "${args[@]}"
        ) | awk -v scope="[$scope]" '{print $0, scope}'
    }

    # List and sort units from both system and user scopes
    (
        list_units_with_scope system "${args[@]}"
        list_units_with_scope user "${args[@]}"
    ) | sort -u
}

# Use fuzzy-finder to select a systemd service and return to the variable
service=$(get_sysd_units \
        | fzf --preview 'systemctl status {1} --no-pager' \
              --preview-window=down:40%:wrap \
              --header 'Select a systemd service to manage' \
              --ansi \
              --border \
        | awk '{print $1}')
[[ -z $service ]] && exit 0

# Use fuzzy-finder to select an action for the chosen service
action=$(printf "start\nstop\nrestart\nenable\ndisable\nstatus\nlogs" \
       | fzf --header "Select action for $service" \
             --border)
[[ -z $action ]] && exit 0

# Run the selected action on the chosen service
if [[ $action == "logs" ]]; then
    sudo journalctl -u "$service" -xe | less
else
    sudo systemctl $action $service
fi