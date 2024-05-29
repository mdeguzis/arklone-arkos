#!/bin/bash
# arklone cloud sync utility
# by ridgek
# Released under GNU GPLv3 license, see LICENSE.md.

printf "\nInstalling cloud sync services\n"

#########
# ARKLONE
#########
git clone --depth 1 https://github.com/ridgekuhn/arklone-arkos /opt/arklone
sudo chown ark:ark /opt/arklone
chmod u+x /opt/arklone/install.sh

source "/opt/arklone/src/config.sh"

echo "Now installing arklone cloud sync utility..."

############
# FILESYSTEM
############
# Create arklone user config dir
# eg,
# /home/user/.config/arklone
# This step is actually redundant since it's already handled by config.sh
# but should stay since it is required for install
if [[ ! -d "${ARKLONE[userCfgDir]}" ]]; then
    mkdir "${ARKLONE[userCfgDir]}"
    chown "${USER}":"${USER}" "${ARKLONE[userCfgDir]}"
fi

# Create backup dir from user setting in ${ARKLONE[userCfg]}
# Should be somewhere easily-accessible for non-Linux users,
# like a FAT partition or samba share
# ArkOS default is /roms/backup
# @todo ArkOS specific
if [[ ! -d "${ARKLONE[backupDir]}" ]]; then
    mkdir "${ARKLONE[backupDir]}"
    chown "${USER}":"${USER}" "${ARKLONE[backupDir]}"

# Create a lock file so we know not to delete on uninstall
else
    touch "${ARKLONE[userCfgDir]}/.backupDir.lock"
fi

if [[ ! -d "${ARKLONE[backupDir]}/rclone" ]]; then
    mkdir "${ARKLONE[backupDir]}/rclone"
    chown "${USER}":"${USER}" "${ARKLONE[backupDir]}/rclone"
fi

########
# RCLONE
########
# Get the system architecture
SYS_ARCH=$(uname -m)

case $SYS_ARCH in
    armv6*)
        SYS_ARCH="arm"
    ;;
    armv7*)
        SYS_ARCH="arm-v7"
    ;;
    aarch64 | arm64)
        SYS_ARCH="arm64"
    ;;
    i386 | i686)
        SYS_ARCH="386"
    ;;
    x86_64)
        SYS_ARCH="amd64"
    ;;
esac

#Get the rclone download URL
RCLONE_PKG="rclone-current-linux-${SYS_ARCH}.deb"
RCLONE_URL="https://downloads.rclone.org/${RCLONE_PKG}"

# Check if user already has rclone installed
if rclone --version >/dev/null 2>&1; then
    # Set a lock file so we can know to restore user's settings on uninstall
    touch "${ARKLONE[userCfgDir]}/.rclone.lock"
fi

# Upgrade the user to the latest rclone
wget "${RCLONE_URL}" -O "${HOME}/${RCLONE_PKG}" \
    && sudo dpkg --force-overwrite -i "${HOME}/${RCLONE_PKG}"

rm "${HOME}/${RCLONE_PKG}"

# Make rclone config directory if it doesn't exit
if [[ ! -d "${HOME}/.config/rclone" ]]; then
    mkdir "${HOME}/.config/rclone"
    chown "${USER}":"${USER}" "${HOME}/.config/rclone"
fi

# Backup user's rclone.conf and move it to ${ARKLONE[backupDir]}/rclone/
# @todo ArkOS-specific
if [[ -f "${HOME}/.config/rclone/rclone.conf" ]]; then
    echo "Backing up and moving your rclone.conf to EASYROMS"

    cp -v "${HOME}/.config/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf.arklone$(date +%s).bak"

    # Suppress errors
    mv "${HOME}/.config/rclone/rclone.conf" "${ARKLONE[backupDir]}/rclone/rclone.conf" 2>/dev/null
fi

# Create user-accessible rclone.conf in ${ARKLONE[backupDir]}
# and symlink it to the default rclone location
touch "${ARKLONE[backupDir]}/rclone/rclone.conf"
ln -sfv "${ARKLONE[backupDir]}/rclone/rclone.conf" "${HOME}/.config/rclone/rclone.conf"
chown "${USER}":"${USER}" "${HOME}/.config/rclone/rclone.conf"
chown "${USER}":"${USER}" "${ARKLONE[backupDir]}/rclone/rclone.conf"

###############
# INOTIFY-TOOLS
###############
# Check if user already has inotify-tools installed
if which inotifywait >/dev/null 2>&1; then
    # Set a lock file so we can know to not remove on uninstall
    touch "${ARKLONE[userCfgDir]}/.inotify-tools.lock"
else
    # Install inotify-tools
    sudo apt update && sudo apt install inotify-tools -y
fi

#########
# ARKLONE
#########
# Make scripts executable
SCRIPTS=($(find "${ARKLONE[installDir]}" -type f -name "*.sh"))
for script in ${SCRIPTS[@]}; do
    sudo chmod a+x "${script}"
done

# Make systemd units directory writeable for user
sudo chown "${USER}":"${USER}" "${ARKLONE[installDir]}/src/systemd/units"



###########
# RETROARCH
###########
# This prevents arklone path units from being triggered when .zip content is temporarily decompressed by RetroArch
cp -v "/home/ark/.config/retroarch/retroarch.cfg" "/home/ark/.config/retroarch/retroarch.cfg.arklone.bak"
cp -v "/home/ark/.config/retroarch32/retroarch.cfg" "/home/ark/.config/retroarch32/retroarch.cfg.arklone.bak"

oldRAstring='cache_directory = ""'
newRAstring='cache_directory = "/tmp"'
sed -i "s|${oldRAstring}|${newRAstring}|" /home/ark/.config/retroarch/retroarch.cfg
sed -i "s|${oldRAstring}|${newRAstring}|" /home/ark/.config/retroarch32/retroarch.cfg

##################
# EMULATIONSTATION
##################
# Modify emulationstation.service
# This runs emulationstation on tty1 instead of detatched
cp "/etc/systemd/system/emulationstation.service" "/etc/emulationstation/emulationstation.service.arklone.bak"

sudo bash -c 'cat <<EOF >"/etc/systemd/system/emulationstation.service"
[Unit]
Description=ODROID-GO2 EmulationStation
After=firstboot.service

[Service]
Type=simple
User=ark
WorkingDirectory=/home/ark
StandardInput=tty
StandardOutput=journal+console
StandardError=journal+console
TTYPath=/dev/tty1
ExecStart=/usr/bin/emulationstation/emulationstation.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target

EOF'

# Modify es_systems.cfg
# Redirects stdin, stdout, stderr
# from the tty EmulationStation is attached to (tty1, per above),
# to the command run from the "Options" menu (/opt/system/ directory)
cp "/etc/emulationstation/es_systems.cfg" "/etc/emulationstation/es_systems.cfg.arklone.bak"

oldESstring='<command>sudo chmod 666 /dev/tty1; %ROM% > /dev/tty1; printf "\\033c" >> /dev/tty1</command>'
newESstring='<command>%ROM% \&lt;/dev/tty \&gt;/dev/tty 2\&gt;/dev/tty</command>'
sudo sed -i "s|${oldESstring}|${newESstring}|" /etc/emulationstation/es_systems.cfg

# Add the arklone settings dialog to EmulationStation "Options" dir
sudo bash -c 'cat <<EOF >"/opt/system/Cloud Settings.sh"
#!/bin/bash
# arklone cloud sync utility
# by ridgek
# Released under GNU GPLv3 license, see LICENSE.md.

/opt/arklone/src/dialogs/scripts/input-listener.sh "/opt/arklone/src/dialogs/settings.sh"
EOF'

sudo chown ark:ark "/opt/system/Cloud Settings.sh"
sudo chmod a+x "/opt/system/Cloud Settings.sh"


echo "Done!"
