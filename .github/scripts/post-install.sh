#!/bin/bash 

defaultRepo="rootzoll"
defaultBranch="v1.7"
me="${0##/*}"
nocolor="\033[0m"
cpu="aarch64"
red="\033[31m"
github_user="rootzoll"
branch="v1.7"
display="lcd"
tweak_boot_drive="true"
wifi_region="US"
baseimage="debian"
configFile="/boot/config.txt"
max_usb_current="max_usb_current=1"
python_libs="grpcio==1.42.0 googleapis-common-protos==1.53.0 toml==0.10.2 j2cli==0.3.10 requests[socks]==2.21.0"
torbox_libs="pytesseract mechanize PySocks urwid Pillow requests setuptools"
homeFile="/home/pi/.bashrc"
file="/home/admin/config.scripts/lndlibs/lightning_pb2_grpc.py"
homeFileAdmin="/home/admin/.bashrc"
blitzpy_version="0.3.0"
blitzpy_wheel="BlitzPy-0.3.0-py2.py3-none-any.whl"

#tor
hdd_path="/mnt/hdd"
download_dir="/home/admin/download"
tor_data_dir="/mnt/hdd/tor"
tor_conf_dir="/mnt/hdd/app-data/tor"
torrc="/etc/tor/torrc"
torrc_bridges="/mnt/hdd/app-data/tor/torrc.d/bridges"
torrc_services="/mnt/hdd/app-data/tor/torrc.d/services"
tor_pkgs="torsocks nyx obfs4proxy python3-stem apt-transport-tor curl gpg"
# tor_deb_repo="tor+http://apow7mjfryruh65chtdydfmqfpj5btws7nbocgtaovhvezgccyjazpqd.onion"
# tor_deb_repo="tor+https://deb.torproject.org"
tor_deb_repo="https://deb.torproject.org"
tor_deb_repo_clean="http://apow7mjfryruh65chtdydfmqfpj5btws7nbocgtaovhvezgccyjazpqd.onion"
tor_deb_repo_pgp_fingerprint="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
distribution="bullseye"
architecture="arm64"
## https://github.com/keroserene/snowflake/commits/master
snowflake_commit_hash="af6e2c30e1a6aacc6e7adf9a31df0a387891cc37"


rootuser="root"
piuser="pi"
defaultpass="raspiblitz"

sed -i "s/^#SystemMaxUse=.*/SystemMaxUse=250M/g" /etc/systemd/journald.conf
sed -i "s/^#SystemMaxFileSize=.*/SystemMaxFileSize=50M/g" /etc/systemd/journald.conf



## default user message
error_msg(){ printf %s"${red}${me}: ${1}${nocolor}\n"; exit 1; }

#Configure environment as noninteractive 
export DEBIAN_FRONTEND=noninteractive

#echo "*** Remove unnecessary packages and update Debian***"
# sudo apt clean -y
# sudo apt autoremove -y
# sudo apt update -y
# sudo apt upgrade -f -y


#echo -e "\n*** Python default libraries & dependencies ***"
pip3 install ${python_libs} ${torbox_libs}


if [ -f "/usr/bin/python3.9" ]; then
  # use python 3.9 if available
  update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1
  echo "python calls python3.9"
elif [ -f "/usr/bin/python3.10" ]; then
  # use python 3.10 if available
  update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
  ln -s /usr/bin/python3.10 /usr/bin/python3.9
  echo "python calls python3.10"
else
  echo "!!! FAIL !!!"
  echo "There is no tested version of python present"
  exit 1
fi

# make sure the pi user is present
if [ "$(compgen -u | grep -c pi)" -eq 0 ];then
  echo "# Adding the user pi"
  adduser --disabled-password --gecos "" pi
  adduser pi sudo
else
  echo "# Pi user already exists"
fi

# set new default password for root user
# echo "root:raspiblitz" | chpasswd
# echo "pi:raspiblitz" | chpasswd 


# limit journald system use

cat /etc/systemd/journald.conf

# change log rotates
# see https://github.com/rootzoll/raspiblitz/issues/394#issuecomment-471535483
echo "
/var/log/syslog
{
  rotate 7
  daily
  missingok
  notifempty
  delaycompress
  compress
  postrotate
    invoke-rc.d rsyslog rotate > /dev/null
  endscript
}
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
{
  rotate 4
  size=100M
  missingok
  notifempty
  compress
  delaycompress
  sharedscripts
  postrotate
    invoke-rc.d rsyslog rotate > /dev/null
  enscript
}
/var/log/kern.log
/var/log/auth.log
{
        rotate 4
        size=100M
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                invoke-rc.d rsyslog rotate > /dev/null
        endscript
}
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages
{
  rotate 4
  weekly
  missingok
  notifempty
  compress
  delaycompress
  sharedscripts
  postrotate
    invoke-rc.d rsyslog rotate > /dev/null
  endscript
}
" | tee ./rsyslog
mv ./rsyslog /etc/logrotate.d/rsyslog
chown root:root /etc/logrotate.d/rsyslog


# echo -e "\n*** ADDING MAIN USER admin ***"
# # based on https://raspibolt.org/system-configuration.html#add-users
# # using the default password 'raspiblitz'
adduser --disabled-password --gecos "" admin
echo "admin:raspiblitz" | chpasswd
adduser admin sudo
chsh admin -s /bin/bash
# configure sudo for usage without password entry
echo '%sudo ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo
# check if group "admin" was created
if [ $(cat /etc/group | grep -c "^admin") -lt 1 ]; then
  echo -e "\nMissing group admin - creating it ..."
  /usr/sbin/groupadd --force --gid 1002 admin
  usermod -a -G admin admin
else
  echo -e "\nOK group admin exists"
fi

# echo -e "\n*** ADDING SERVICE USER bitcoin"
# based on https://raspibolt.org/system-configuration.html#add-users
# create user and set default password for user
adduser --disabled-password --gecos "" bitcoin
echo "bitcoin:raspiblitz" | chpasswd
# make home directory readable
chmod 755 /home/bitcoin

# WRITE BASIC raspiblitz.info to sdcard
# if further info gets added .. make sure to keep that on: blitz.preparerelease.sh
touch /home/admin/raspiblitz.info
echo "baseimage=${baseimage}" | tee raspiblitz.info
echo "cpu=${cpu}" | tee -a raspiblitz.info
echo "displayClass=headless" | tee -a raspiblitz.info
mv raspiblitz.info /home/admin/
chmod 755 /home/admin/raspiblitz.info
chown admin:admin /home/admin/raspiblitz.info

# echo -e "\n*** ADDING GROUPS FOR CREDENTIALS STORE ***"
# access to credentials (e.g. macaroon files) in a central location is managed with unix groups and permissions
/usr/sbin/groupadd --force --gid 9700 lndadmin
/usr/sbin/groupadd --force --gid 9701 lndinvoice
/usr/sbin/groupadd --force --gid 9702 lndreadonly
/usr/sbin/groupadd --force --gid 9703 lndinvoices
/usr/sbin/groupadd --force --gid 9704 lndchainnotifier
/usr/sbin/groupadd --force --gid 9705 lndsigner
/usr/sbin/groupadd --force --gid 9706 lndwalletkit
/usr/sbin/groupadd --force --gid 9707 lndrouter

echo -e "\n*** SHELL SCRIPTS & ASSETS ***"
# copy raspiblitz repo from github
git config --global user.name "${github_user}"
git config --global user.email "johndoe@example.com"
git clone -b "${branch}" https://github.com/${github_user}/raspiblitz.git
cp -r ./raspiblitz/home.admin/*.* /home/admin
cp ./raspiblitz/home.admin/.tmux.conf /home/admin
cp -r ./raspiblitz/home.admin/assets /home/admin/
cp -r ./raspiblitz/home.admin/config.scripts /home/admin/
cp -r ./raspiblitz/home.admin/setup.scripts /home/admin/

chmod +x /home/admin/*.sh
chmod +x /home/admin/config.scripts/*.sh
chmod +x /home/admin/setup.scripts/*.sh
chown -R admin:admin /home/admin
echo -e "\n Script Import Complete"
echo -e "\n*** INSTALLING BlitzPy Version: ${blitzpy_version} ***"
pip3 install "./raspiblitz/home.admin/BlitzPy/dist/${blitzpy_wheel}" >/dev/null 2>&1
echo -e "\n BlitzPy Installation Complete"
# make sure lndlibs are patched for compatibility for both Python2 and Python3
! grep -Fxq "from __future__ import absolute_import" "${file}" && sed -i -E '1 a from __future__ import absolute_import' "${file}"
! grep -Eq "^from . import.*" "${file}" && sed -i -E 's/^(import.*_pb2)/from . \1/' "${file}"

# add /sbin to path for all
bash -c "echo 'PATH=\$PATH:/sbin' >> /etc/profile"

echo -e "\n*** RASPIBLITZ EXTRAS ***"


bash -c "echo '' >> /home/admin/.bashrc"
bash -c "echo '# https://github.com/rootzoll/raspiblitz/issues/1784' >> /home/admin/.bashrc"
bash -c "echo 'NG_CLI_ANALYTICS=ci' >> /home/admin/.bashrc"

echo -e "\n*** RASPIBLITZ EXTRAS Installed ***"

# raspiblitz custom command prompt #2400
if ! grep -Eq "^[[:space:]]*PS1.*₿" /home/admin/.bashrc; then
    sed -i '/^unset color_prompt force_color_prompt$/i # raspiblitz custom command prompt https://github.com/rootzoll/raspiblitz/issues/2400' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i raspiIp=$(hostname -I | cut -d " " -f1)' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i if [ "$color_prompt" = yes ]; then' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i \    PS1=\x27${debian_chroot:+($debian_chroot)}\\[\\033[00;33m\\]\\u@$raspiIp:\\[\\033[00;34m\\]\\w\\[\\033[01;35m\\]$(__git_ps1 "(%s)") \\[\\033[01;33m\\]₿\\[\\033[00m\\] \x27' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i else' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i \    PS1=\x27${debian_chroot:+($debian_chroot)}\\u@$raspiIp:\\w₿ \x27' /home/admin/.bashrc
    sed -i '/^unset color_prompt force_color_prompt$/i fi' /home/admin/.bashrc
fi


echo -e "\n*** FUZZY FINDER KEY BINDINGS ***"
if ! grep -Fxq "source /usr/share/doc/fzf/examples/key-bindings.bash" $homeFile; then
  bash -c "echo 'source /usr/share/doc/fzf/examples/key-bindings.bash' >> /home/admin/.bashrc"
  echo "key-bindings added to $homeFile"
else
  grep -c "source /usr/share/doc/fzf/examples/key-bindings.bash" $homeFile
  echo "key-bindings already in $homeFile"
fi

echo -e "\n*** AUTOSTART ADMIN SSH MENUS ***"

if ! grep -Fxq "automatically start main menu" $homeFile; then
  # bash autostart for admin
  bash -c "echo '# shortcut commands' >> /home/admin/.bashrc"
  bash -c "echo 'source /home/admin/_commands.sh' >> /home/admin/.bashrc"
  bash -c "echo '# automatically start main menu for admin unless' >> /home/admin/.bashrc"
  bash -c "echo '# when running in a tmux session' >> /home/admin/.bashrc"
  bash -c "echo 'if [ -z \"\$TMUX\" ]; then' >> /home/admin/.bashrc"
  bash -c "echo '    ./00raspiblitz.sh newsshsession' >> /home/admin/.bashrc"
  bash -c "echo 'fi' >> /home/admin/.bashrc"
  echo "autostart added to $homeFile"
else
  echo "autostart already in $homeFile"
fi

echo -e "\n*** SWAP FILE ***"
# based on https://stadicus.github.io/RaspiBolt/raspibolt_20_pi.html#move-swap-file
# but just deactivating and deleting old (will be created alter when user adds HDD)
dphys-swapfile swapoff
dphys-swapfile uninstall


echo -e "\n*** INCREASE OPEN FILE LIMIT ***"
# based on https://raspibolt.org/security.html#increase-your-open-files-limit
sed --in-place -i "56s/.*/*    soft nofile 256000/" /etc/security/limits.conf
bash -c "echo '*    hard nofile 256000' >> /etc/security/limits.conf"
bash -c "echo 'root soft nofile 256000' >> /etc/security/limits.conf"
bash -c "echo 'root hard nofile 256000' >> /etc/security/limits.conf"
bash -c "echo '# End of file' >> /etc/security/limits.conf"
sed --in-place -i "23s/.*/session required pam_limits.so/" /etc/pam.d/common-session
sed --in-place -i "25s/.*/session required pam_limits.so/" /etc/pam.d/common-session-noninteractive
bash -c "echo '# end of pam-auth-update config' >> /etc/pam.d/common-session-noninteractive"



# *** CACHE DISK IN RAM & KEYVALUE-STORE***
echo "Activating CACHE RAM DISK ... "
# /home/admin/_cache.sh ramdisk on

# echo "# Turn ON: RAMDISK"

if ! grep -Eq '^tmpfs.*/var/cache/raspiblitz' /etc/fstab; then

    if grep -Eq '/var/cache/raspiblitz' /etc/fstab; then
        # entry is in file but most likely just disabled -> re-enable it
        sed -i -E 's|^#(tmpfs.*/var/cache/raspiblitz.*)$|\1|g' /etc/fstab
    else
        # missing -> add
        echo "" | tee -a /etc/fstab >/dev/null
        echo "tmpfs         /var/cache/raspiblitz  tmpfs  nodev,nosuid,size=32M  0  0" | tee -a /etc/fstab >/dev/null
    fi
fi

if ! findmnt -l /var/cache/raspiblitz >/dev/null; then
    mkdir -p /var/cache/raspiblitz
    # mount /var/cache/raspiblitz
fi



# # /home/admin/_cache.sh keyvalue on

echo "# Turn ON: KEYVALUE-STORE (REDIS)"
# edit config: dont save to disk
sed -i "/^save .*/d" /etc/redis/redis.conf

# clean old databases if exist
rm /var/lib/redis/dump.rdb 2>/dev/null




# *** FATPACK *** (can be activated by parameter - see details at start of script)
echo -e "\n*** FATPACK ***"
echo "* Adding nodeJS Framework ..."
NODEJSVERSION="v16.0.0"
# get checksums from -> https://nodejs.org/dist/vx.y.z/SHASUMS256.txt (tar.xs files)
CHECKSUM_linux_arm64="c6dc688de6373049f21cb1ca4f2ceefe80a5d711e301b8d54fd0a7c36a406b03"



# determine nodeJS VERSION and DISTRO
# isARM=$(uname -m | grep -c 'arm')
# isAARCH64=$(uname -m | grep -c 'aarch64')
# isX86_64=$(uname -m | grep -c 'x86_64')
# if [ ${isARM} -eq 1 ] ; then
#   DISTRO="linux-armv7l"
#   CHECKSUM="${CHECKSUM_linux_armv7l}"
# elif [ ${isAARCH64} -eq 1 ] ; then
#   DISTRO="linux-arm64"
#   CHECKSUM="${CHECKSUM_linux_arm64}"
# elif [ ${isX86_64} -eq 1 ] ; then
#   DISTRO="linux-x64"
#   CHECKSUM="${CHECKSUM_linux_x64}"
# elif [ ${#DISTRO} -eq 0 ]; then
#   echo "# FAIL: Was not able to determine architecture"
#   exit 1
# fi
DISTRO="linux-arm64"
CHECKSUM="${CHECKSUM_linux_arm64}"

echo -e "distro ${DISTRO}"
# check if nodeJS was installed


# install latest nodejs
# https://github.com/nodejs/help/wiki/Installation
echo "*** Install NodeJS $NODEJSVERSION-$DISTRO ***"
echo "VERSION: ${NODEJSVERSION}"
echo "DISTRO: ${DISTRO}"
echo "CHECKSUM: ${CHECKSUM}"
echo ""

# download
wget https://nodejs.org/dist/$NODEJSVERSION/node-$NODEJSVERSION-$DISTRO.tar.xz -P /home/admin/download
# checksum
isChecksumValid=$(sha256sum /home/admin/download/node-$NODEJSVERSION-$DISTRO.tar.xz | grep -c "${CHECKSUM}")
if [ ${isChecksumValid} -eq 0 ]; then
    echo "FAIL: The checksum of node-$NODEJSVERSION-$DISTRO.tar.xz is NOT ${CHECKSUM}"
    rm -f /home/admin/download/node-$NODEJSVERSION-$DISTRO.tar.xz*
    exit 1
fi
echo "OK CHECKSUM of nodeJS is OK"
sleep 3
# install
mkdir -p /usr/local/lib/nodejs
tar -xJvf /home/admin/download/node-$NODEJSVERSION-$DISTRO.tar.xz -C /usr/local/lib/nodejs
rm -f /home/admin/download/node-$NODEJSVERSION-$DISTRO.tar.xz* 
export PATH=/usr/local/lib/nodejs/node-$NODEJSVERSION-$DISTRO/bin:$PATH
ln -sf /usr/local/lib/nodejs/node-$NODEJSVERSION-$DISTRO/bin/node /usr/bin/node
ln -sf /usr/local/lib/nodejs/node-$NODEJSVERSION-$DISTRO/bin/npm /usr/bin/npm
ln -sf /usr/local/lib/nodejs/node-$NODEJSVERSION-$DISTRO/bin/npx /usr/bin/npx
# add to PATH permanently
bash -c "echo 'PATH=\$PATH:/usr/local/lib/nodejs/node-${NODEJSVERSION}-${DISTRO}/bin/' >> /etc/profile"
echo ""
  
# check if nodeJS was installed
nodeJSInstalled=$(node -v | grep -c "v1.")
if [ ${nodeJSInstalled} -eq 0 ]; then
    echo "FAIL - Was not able to install nodeJS"
    echo "ABORT - nodeJs install"
    exit 1
fi
echo "OK - nodeJS installed"



# needed for RTL
# https://github.blog/2021-02-02-npm-7-is-now-generally-available/
echo "# Update npm to v7"
npm install --global npm@7
echo "Installed nodeJS $(node -v)"


# *** UPDATE FALLBACK NODE LIST (only as part of fatpack) *** see https://github.com/rootzoll/raspiblitz/issues/1888
echo "*** FALLBACK NODE LIST ***"
curl -H "Accept: application/json; indent=4" https://bitnodes.io/api/v1/snapshots/latest/ -o /home/admin/fallback.nodes
chown admin:admin /home/admin/fallback.nodes

# *** BOOTSTRAP ***
echo -e "\n*** RASPI BOOTSTRAP SERVICE ***"
chmod +x /home/admin/_bootstrap.sh
cp /home/admin/assets/bootstrap.service /etc/systemd/system/bootstrap.service
systemctl enable bootstrap

# *** BACKGROUND TASKS ***
echo -e "\n*** RASPI BACKGROUND SERVICE ***"
chmod +x /home/admin/_background.sh
cp /home/admin/assets/background.service /etc/systemd/system/background.service
systemctl enable background

# # *** BACKGROUND SCAN ***
# /home/admin/_background.scan.sh install
  # write systemd service
  cat > /etc/systemd/system/background.scan.service <<EOF
# Monitor the RaspiBlitz State
# /etc/systemd/system/background.scan.service
[Unit]
Description=RaspiBlitz Background Monitoring Service
Wants=redis.service
After=redis.service
[Service]
User=root
Group=root
Type=simple
ExecStart=/home/admin/_background.scan.sh
Restart=always
TimeoutSec=10
RestartSec=10
StandardOutput=journal
[Install]
WantedBy=multi-user.target
EOF

# enable systemd service & exit
systemctl enable background.scan
echo "# background.scan.service will start after reboot or calling: sudo systemctl start background.scan"

# #######
# # TOR #
# #######
# /home/admin/config.scripts/tor.install.sh install || exit 1

echo -e "*** Installing tor (but not run it yet - needs HDD connected )***\n"


curl https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --import
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

echo -e "\n--> Configuring pluggable transports ***"
#VERIFY LATER
setcap 'cap_net_bind_service=+ep' /usr/bin/obfs4proxy

# Install Snowflake
# nyxnor: unfortunately it reaches TPO domain for a lib which I can't fix
if [ ! -f /usr/bin/snowflake-proxy ] || [ ! -f /usr/bin/snowflake-client ]; then
  rm -rf ./snowflake
  git clone https://github.com/keroserene/snowflake.git ./snowflake
  if [ ! -d ./snowflake ]; then
    echo "FAIL: COULDN'T CLONE THE SNOWFLAKE REPOSITORY!"
    echo "INFO: The Snowflake repository may be blocked or offline!"
    echo "INFO: Please try again later and if the problem persists, please report it"
  else
    git -C ./snowflake -c advice.detachedHead=false checkout "${snowflake_commit_hash}"
    goVersion="1.17.3"
    downloadFolder="/home/admin/download"
    # bash /home/admin/config.scripts/bonus.go.sh on
    . /etc/profile # get Go vars - needed if there was no log-out since Go installed
    printf "Check Framework: Go\n"
    if go version 2>/dev/null | grep -q "go" ; then
        printf "\nVersion of Go requested already installed.\n"
        go version
        printf "\n"
    else
        architecture="$(uname -m)"
        case "${architecture}" in
            arm*) goOSversion="armv6l";;
            aarch64) goOSversion="arm64";;
            x86_64) goOSversion="amd64";;
            *) printf %s"Not available for architecture=${architecture}\n"; exit 1
        esac
        printf %s"\n*** Installing Go v${goVersion} for ${goOSversion} \n***"
        wget https://dl.google.com/go/go${goVersion}.linux-${goOSversion}.tar.gz -P ${downloadFolder}
        if [ ! -f "${downloadFolder}/go${goVersion}.linux-${goOSversion}.tar.gz" ]; then
            printf "!!! FAIL !!! Download failed.\n"
            rm -fv go${goVersion}.linux-${goOSversion}.tar.gz*
            exit 1
        fi
        tar -C /usr/local -xzf ${downloadFolder}/go${goVersion}.linux-${goOSversion}.tar.gz
        rm -fv ${downloadFolder}/go${goVersion}.linux-${goOSversion}.tar.gz*
        mkdir -v /usr/local/gocode
        chmod -v 777 /usr/local/gocode
        export GOROOT=/usr/local/go
        export PATH=$PATH:$GOROOT/bin
        export GOPATH=/usr/local/gocode
        export PATH=$PATH:$GOPATH/bin
        grep -q "GOROOT=" /etc/profile || { printf "\nGOROOT=/usr/local/go\nPATH=\$PATH:\$GOROOT/bin/\nGOPATH=/usr/local/gocode\nPATH=\$PATH:\$GOPATH/bin/\n\n" | tee -a /etc/profile; }
        go env -w GOPATH=/usr/local/gocode # set GOPATH https://github.com/golang/go/wiki/SettingGOPATH
        go version | grep -q "go" || { printf "FAIL: Unable to install Go\n"; exit 1; }
        printf %s"Installed $(go version 2>/dev/null)\n\n"
    fi


    . /etc/profile ## GOPATH
    export GO111MODULE="on"
    cd ./snowflake/proxy || exit 1
    echo -e "\n*** Installing snowflake-proxy ***"
    go get
    go build
    cp proxy /usr/bin/snowflake-proxy
    cd ../client || exit 1
    echo -e "\n*** Installing snowflake-client ***"
    go get
    go build
    cp client /usr/bin/snowflake-client
    cd ~ || exit 1
    rm -rf ./snowflake
  fi
else
  echo -e "\n--> Snowflake client and proxy already installed ***\n"
fi

# install tor
echo -e "\n*** Install Tor ***"
apt-get -o Dpkg::Options::="--force-confold" install -y tor
apt-get install -y ${tor_pkgs}

echo -e "\n*** Adding deb.torproject.org keyring ***"
if ! curl -s -x socks5h://127.0.0.1:9050 --connect-timeout 10 "${tor_deb_repo_clean}/torproject.org/${tor_deb_repo_pgp_fingerprint}.asc" | gpg --dearmor | tee /etc/apt/trusted.gpg.d/torproject.gpg >/dev/null; then
  echo "!!! FAIL: Was not able to import deb.torproject.org key";
  exit 1
fi
echo "- OK key added"

echo -e "\n*** Adding Tor Sources ***"
echo "
deb [arch=${architecture}] ${tor_deb_repo}/torproject.org ${distribution} main
deb-src [arch=${architecture}] ${tor_deb_repo}/torproject.org  ${distribution} main
" | tee /etc/apt/sources.list.d/tor.list
echo "- OK sources added"

echo -e "\n*** Reinstall ***"
# apt-get update -y
apt-get -o Dpkg::Options::="--force-confold" install -y tor
apt-get install -y ${tor_pkgs}


apt-get autoremove -y
echo "*** raspiblitz.info ***"
cat /home/admin/raspiblitz.info

