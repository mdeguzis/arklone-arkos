#!/bin/bash
# arklone cloud sync utility
# by ridgek
# Released under GNU GPLv3 license, see LICENSE.md.

# Listen to input and convert to keycodes for command input
#
# Uses oga_controls
# @see https://github.com/christianhaitian/oga_controls
#
# @param $1 Absolute path to the command to run

[[ ${#ARKLONE[@]} -gt 0 ]] || source "/opt/arklone/src/config.sh"

RUNCOMMAND="${1}"

# Get device type
# Anbernic RG351x
if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
  PARAM_DEVICE="anbernic"

# Ambernic RG353M
elif [[ -e "/dev/input/by-path/platform-singleadc-joypad-event-joystick" ]]; then
  PARAM_DEVICE="anbernic"

# Anbernic RG351x
# ODROID Go 2
elif [[ -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]]; then
      PARAM_DEVICE="oga"
    else
      PARAM_DEVICE="rk2020"
    fi

# ODROID Go 3
elif [[ -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
  PARAM_DEVICE="ogs"

# Gameforce Chi
elif [[ -e "/dev/input/by-path/platform-gameforce-gamepad-event-joystick" ]]; then
  PARAM_DEVICE="chi"
fi

# https://github.com/christianhaitian/arkos/blob/main/ports/docs/packaging.md
# Also see: /usr/bin/osk
if [[ $PARAM_DEVICE ]]; then
    # This gets movement, but the keys do nothing. Using inputmon in each script to test A or B button
    #sudo /usr/local/bin/oga_controls "${RUNCOMMAND}" "${PARAM_DEVICE}" &
    if [[ -z $(pgrep -f gptokeyb) ]] && [[ -z $(pgrep -f oga_controls) ]]; then
	  sudo chmod 666 /dev/uinput
	  export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
	  /opt/inttools/gptokeyb -1 "python3" -c "/opt/inttools/keys.gptk" > /dev/null &
	  disown
	  set_gptokeyb="Y"
    fi
    export TERM=linux
    export XDG_RUNTIME_DIR=/run/user/$UID/
fi

# Run/source the command in a subshell so it has access to ${ARKLONE[@]}
# but can still use `exit` without exiting this script
(. "${RUNCOMMAND}")

EXIT_CODE=$?

# Teardown
if [[ $PARAM_DEVICE ]]; then
    sudo kill -s SIGKILL $(pidof oga_controls)
fi

if [[ ! -z "$set_gptokeyb" ]]; then
  pgrep -f gptokeyb | sudo xargs kill -9
  unset SDL_GAMECONTROLLERCONFIG_FILE
fi


exit $EXIT_CODE

