#!/bin/bash
[ "$(type -t loadConfig)" = "function" ] || source "/opt/arklone/functions/loadConfig.sh"

# Set default settings
declare -A ARKLONE
ARKLONE=(
	# Install Paths
	[installDir]="/opt/arklone"
	[userCfgDir]="${HOME}/.config/arklone"
	# @todo ArkOS-specific
	# [backupDir]="/roms/backup"

	# arklone config file
	[userCfg]="${ARKLONE[userCfgDir]}/arklone.cfg"

	# Dirty boot lock file
	# @todo ArkOS-specific
	[dirtyBoot]="${ARKLONE[userCfgDir]}/dirtyboot"

	# rclone
	# @todo ArkOS-specific
	# [rcloneConf]="/home/ark/.config/rclone/rclone.conf"
	# [remote]=""
	[filterDir]="${ARKLONE[installDir]}/rclone/filters"

	# Log
	# [log]="/dev/shm/arklone.log"

	# RetroArch
	# @todo ArkOS-specific
	# [retroarchContentRoot]="/roms"
	# [retroarchCfg]="/home/user/.config/retroarch/retroarch.cfg"

	# systemd
	[autoSync]=$(systemctl list-unit-files arkloned* | grep "enabled" | cut -d " " -f 1)
	[unitsDir]="${ARKLONE[installDir]}/systemd/units"
	[ignoreDir]="${ARKLONE[installDir]}/systemd/scripts/ignores"

	# Whiptail settings
	[whiptailTitle]="arklone cloud sync utility"
)

# Recreate userCfg if missing
if [ ! -f "${ARKLONE[userCfg]}" ]; then
	# Create userCfgDir if missing
	[ -d "${ARKLONE[userCfgDir]}" ] || mkdir "${ARKLONE[userCfgDir]}"

	cp "${ARKLONE[installDir]}/arklone.cfg.orig" "${ARKLONE[userCfg]}"
fi

# Load the user's config file
loadConfig "${ARKLONE[userCfg]}" ARKLONE
