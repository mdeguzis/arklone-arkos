#!/bin/bash
# arklone cloud sync utility
# by ridgek
# Released under GNU GPLv3 license, see LICENSE.md.

source "/opt/arklone/src/config.sh"

# Uninstall arklone
# @param $1 {boolean} Keep install dir if true
KEEP_INSTALL_DIR=$1

#########
# SYSTEMD
#########
# Get list of installed units
UNITS=($(systemctl list-unit-files | grep "arklone" | cut -d ' ' -f 1))

# Remove arklone from systemd
if [[ "${#UNITS[@]}" -gt 0 ]]; then
    for unit in ${UNITS[@]}; do
        sudo systemctl disable "${unit}"
    done
fi

###############
# INOTIFY-TOOLS
###############
if [[ ! -f "${ARKLONE[userCfgDir]}/.inotify-tools.sh" ]]; then
    sudo apt remove inotify-tools -y
fi

########
# RCLONE
########
# If user already had rclone installed,
# restore rclone.conf to original state
if [[ -f "${ARKLONE[userCfgDir]}/.rclone.lock" ]]; then
    echo "Restoring your rclone settings..."

    cp "${ARKLONE[backupDir]}/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf.arklone$(date +%s).bak"

# Else, uninstall rclone
else
    sudo dpkg -P rclone
fi

rm "${HOME}/.config/rclone/rclone.conf"
mv "${ARKLONE[backupDir]}/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf"

############
# FILESYSTEM
############
# Remove user-accessible backup dir if it did not exist on install
if [[ ! -f "${ARKLONE[userCfgDir]}/.backupDir.lock" ]]; then
    rm -rf "${ARKLONE[backupDir]}"

# Else, only remove the directories created by arklone
else
    rm -rf "${ARKLONE[backupDir]}/rclone"
fi

#########
# ARKLONE
#########
# Remove arklone user config dir
rm -rf "${ARKLONE[userCfgDir]}"

# Remove arklone
if [[ ! $KEEP_INSTALL_DIR ]]; then
    sudo rm -rf "${ARKLONE[installDir]}"
fi

# Remove options script entry
rm -f "/opt/system/Cloud Settings.sh"

echo "Uninstallation complete. Thanks for trying arklone!"

