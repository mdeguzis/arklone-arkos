#!/bin/bash
# arklone cloud sync utility
# by ridgek
# Released under GNU GPLv3 license, see LICENSE.md.

source "/opt/arklone/config.sh"
source "${ARKLONE[installDir]}/functions/loadConfig.sh"
source "${ARKLONE[installDir]}/functions/editConfig.sh"
# @todo Replace printMenu with ${!array[@]}
source "${ARKLONE[installDir]}/functions/printMenu.sh"
source "${ARKLONE[installDir]}/dialogs/functions/alreadyRunning.sh"
source "${ARKLONE[installDir]}/systemd/scripts/functions/getRootInstanceNames.sh"

#############
# CONTROLLERS
#############
# Manual backup ArkOS settings
function manualBackupArkOS() {
	local keep="${1}"

	. "${ARKLONE[installDir]}/rclone/scripts/sync-arkos-backup.sh"

	if [ $? = 0 ]; then
		# Delete ArkOS settings backup file
		if [ $keep != 0 ]; then
			sudo rm -v "${ARKLONE[backupDir]}/arkosbackup.tar.gz"
		fi

		return 0
	else
		return $?
	fi
}

# Change all retroarch.cfgs to recommended settings
function retroarchSetRecommended() {
	# Get array of all retroarch.cfg instances
	local retroarchs=(${ARKLONE[retroarchCfg]})

	# Change user settings
	# Use "${retroarchs[0]}/saves" as parent for savefiles and savestates
	# for all instances of retroarch.cfg
	for retroarchCfg in ${retroarchs[@]}; do
		. "${ARKLONE[installDir]}/retroarch/scripts/set-recommended-settings.sh" "${retroarchCfg}" "$(dirname "${retroarchs[0]}")/saves"
	done
}

#######
# VIEWS
#######
# Point-of-entry dialog
function homeScreen() {
	# Set automatic sync mode string
	local ableString=$([ "${ARKLONE[autoSync]}" ] && echo "Disable" || echo "Enable")

	local selection=$(whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--menu "Choose an option:" \
			16 60 8 \
			"1" "Set cloud service (now: $([ "${ARKLONE[remote]}" ] && echo "${ARKLONE[remote]}" || echo "NONE"))" \
			"2" "Manually sync saves" \
			"3" "${ableString} automatic saves sync" \
			"4" "Manual backup/sync ArkOS Settings" \
			"5" "Regenerate RetroArch path units" \
			"x" "Exit" \
		3>&1 1>&2 2>&3 \
	)

	# Send user to selected screen
	# @todo Add screen to dump log to SD card
	case $selection in
		1) setCloudScreen ;;
		2) manualSyncSavesScreen ;;
		3) autoSyncSavesScreen ;;
		4) manualBackupArkOSScreen ;;
		5) regenRAunitsScreen ;;
	esac
}

# First run dialog
function firstRunScreen() {
	# Check if rclone is configured
	if [ -z "$(rclone listremotes 2>/dev/null)" ]; then
		whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--msgbox "It looks like you haven't configured any rclone remotes yet! Please see the documentation at:\nhttps://github.com/ridgekuhn/arklone-arkos\nand\nhttps://rclone.org/docs/" \
			16 56 8

		exit
	fi

	# Set recommended RetroArch settings
	whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--yesno "Welcome to arklone!\nWould you like to automatically configure RetroArch to the recommended settings?" \
			16 56 8

	if [ $? = 0 ]; then
		whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--infobox \
				"Please wait while we configure your settings..." \
				16 56 8

		retroarchSetRecommended
	fi

	# Generate RetroArch systemd path units
	whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--msgbox "We will now install several components for syncing RetroArch savefiles/savestates. This process may take several minutes, depending on your configuration." \
			16 56 8

	regenRAunitsScreen
}

# Cloud service selection dialog
function setCloudScreen() {
	# Get list of rclone remotes
	local remotes=($(rclone listremotes | cut -d ':' -f 1))

	# @todo Replace printMenu with ${!array[@]}
	local selection=$(whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--menu \
			"Choose a cloud service:" \
			16 60 8 \
			$(printMenu "${remotes[@]}") \
		3>&1 1>&2 2>&3 \
	)

	# Save user selection and reload config
	if [ "${selection}" ]; then
		editConfig "remote" "${remotes[$selection]}" "${ARKLONE[userCfg]}"
		loadConfig "${ARKLONE[userCfg]}" ARKLONE
	fi

	homeScreen
}

# Manual sync savefiles/savestates dialog
function manualSyncSavesScreen() {
	local script="${ARKLONE[installDir]}/rclone/scripts/send-and-receive-saves.sh"
	local instances=($(getRootInstanceNames))

	# Build a list of local directories
	local localdirs=$(
		for instance in ${instances[@]}; do
			local filterString=""

			# Populate ${filterString} if filter names begin with "retroarch-"
			if grep "retroarch-" <<<"${instance##*@}" >/dev/null 2>&1; then
				# Get array of filters from instance name
				local filters=($(tr '|' '\n' <<<"${instance##*@}"))

				# Separate multiple filters with pipe | and remove "retroarch-" prefix
				if [ "${#filters[@]}" -gt 1 ]; then
					filterString="($(
						for filter in ${filters[@]}; do
							printf "${filter##retroarch-}|"
						done
					))"
				# Just remove "retroarch-" prefix
				else
					filterString="(${filters##retroarch-})"
				fi
			fi

			# Print localdir and filter
			# eg,
			# "/path/to/foo(savefile|savestate)"
			printf "${instance%@*@*}${filterString/%|)/)} "
		done
	)

	# Check if sync script is already running
	alreadyRunning "${script}"

	if [ $? != 0 ]; then
		homeScreen

	# Allow user to select a directory to sync
	# @todo Add a "sync all" option
	else
		# @todo Replace printMenu with ${!array[@]}
		local selection=$(whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--menu \
				"Choose a directory to sync with (${ARKLONE[remote]}):" \
				16 60 8 \
				$(printMenu "${localdirs}") \
			3>&1 1>&2 2>&3 \
		)

		if [ ! -z "${selection}" ]; then
			local instance=${instances[$selection]}
			IFS="@" read -r localdir remotedir filter <<< "${instance}"

			# Sync the local and remote directories
			. "${script}" "${instance}"

			if [ $? = 0 ]; then
				whiptail \
					--title "${ARKLONE[whiptailTitle]}" \
					--msgbox \
						"${localdir} synced to ${ARKLONE[remote]}:${remotedir}. Log saved to ${ARKLONE[log]}." \
						16 56 8
			else
				whiptail \
					--title "${ARKLONE[whiptailTitle]}" \
					--msgbox \
						"Update failed. Please check the log file at ${ARKLONE[log]}." \
						16 56 8
			fi
		fi

		homeScreen
	fi
}

# Enable/Disable auto savefile/savestate syncing
function autoSyncSavesScreen() {
	whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--infobox \
			"Please wait while we configure your settings..." \
			16 56 8

	# Enable or disable path units
	local autosync=(${ARKLONE[autoSync]})

	if [ "${#autosync[@]}" = 0 ]; then
		. "${ARKLONE[installDir]}/systemd/scripts/enable-path-units.sh"
	else
		. "${ARKLONE[installDir]}/systemd/scripts/disable-path-units.sh"
	fi

	# Reset ${ARKLONE[autoSync]}
	# @todo This should be its own function
	ARKLONE[autoSync]=$(systemctl list-unit-files arkloned* | grep "enabled" | cut -d " " -f 1)

	homeScreen
}

# Manual backup ArkOS settings screen
function manualBackupArkOSScreen() {
	local script="${ARKLONE[installDir]}/rclone/scripts/send-arkos-backup.sh"

	alreadyRunning "${script}"

	if [ $? = 0 ]; then
		whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--yesno \
				"This will create a backup of your settings at ${ARKLONE[backupDir]}/arkosbackup.tar.gz. Do you want to keep this file after it is uploaded to ${ARKLONE[remote]}?" \
				16 56

		# Store whether user wanted to keep the arkosbackup.tar.gz or not
		local keep=$?

		whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--infobox \
				"Please wait while we back up your settings..." \
				16 56 8

		# manualBackupArkOS calls ${script}
		manualBackupArkOS "${keep}"

		if [ $? = 0 ]; then
			whiptail \
				--title "${ARKLONE[whiptailTitle]}" \
				--msgbox \
					"ArkOS backup synced to ${ARKLONE[remote]}:ArkOS. Log saved to ${ARKLONE[log]}." \
					16 56 8
		else
			whiptail \
				--title "${ARKLONE[whiptailTitle]}" \
				--msgbox \
					"Update failed. Please check the log file at ${ARKLONE[log]}." \
					16 56 8
		fi
	fi

	homeScreen
}

# Regenerate RetroArch savestates/savefiles units screen
function regenRAunitsScreen() {
	local script="${ARKLONE[installDir]}/systemd/scripts/generate-retroarch-units.sh"

	whiptail \
		--title "${ARKLONE[whiptailTitle]}" \
		--infobox \
			"Please wait while we configure your settings..." \
			16 56 8

	# Delete old retroarch path units and generate new ones
	. "${script}" true

	# Fix incompatible settings
	# @todo ArkOS-specific
	if [ $? = 65 ]; then
		whiptail \
			--title "${ARKLONE[whiptailTitle]}" \
			--yesno \
				"Due to a bug in ArkOS, the following settings are incompatible with automatic syncing. Would you like to use the recommended settings?:\n
				savefiles_in_content_dir\n
				savestates_in_content_dir" \
			16 56 8

		if [ $? = 1 ]; then
			whiptail \
				--title "${ARKLONE[whiptailTitle]}" \
				--msgbox "No action has been taken. You may still use the manual sync feature for RetroArch savefiles/savestates, but you will not be able to automatically sync them until the incompatible settings in retroarch.cfg are resolved." \
			16 56 8

		# Change user's settings
		else
			retroarchSetRecommended
		fi
	fi

	homeScreen
}

#####
# RUN
#####
# If ${ARKLONE[remote]} doesn't exist, assume this is the user's first run
if [ -z "${ARKLONE[remote]}" ]; then
	firstRunScreen

	# Exit here so user doesn't quit back to homeScreen
	exit
fi

homeScreen

