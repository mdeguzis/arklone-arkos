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

if [[ -z $(pgrep -f gptokeyb) ]] && [[ -z $(pgrep -f oga_controls) ]]; then
  sudo chmod 666 /dev/uinput
  export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
  /opt/inttools/gptokeyb -1 "python3" -c "/opt/inttools/keys.gptk" > /dev/null &
  disown
  set_gptokeyb="Y"
fi
export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

# Run/source the command in a subshell so it has access to ${ARKLONE[@]}
# but can still use `exit` without exiting this script
(. "${RUNCOMMAND}")

EXIT_CODE=$?

if [[ ! -z "$set_gptokeyb" ]]; then
  pgrep -f gptokeyb | sudo xargs kill -9
  unset SDL_GAMECONTROLLERCONFIG_FILE
fi


exit $EXIT_CODE

