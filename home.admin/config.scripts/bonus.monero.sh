#!/bin/bash
moneroVersion="0.18.1.2"

source /mnt/hdd/raspiblitz.conf
source /home/admin/raspiblitz.info

#create monerod config file
create_config_file () {
  if [ ! -f "/mnt/hdd/monero/${prefix}monerod.conf" ];then
   echo "# /mnt/hdd/monero/${prefix}monerod.conf

# Data directory (blockchain db and indices)
data-dir=/mnt/hdd/monero/.bitmonero

# Log file
log-file=/mnt/hdd/monero/monerod.log

# P2P configuration
# p2p-bind-ip=0.0.0.0            # Bind to all interfaces (the default)
# p2p-bind-port=18080            # Bind to default port

# RPC configuration
rpc-restricted-bind-ip=0.0.0.0            # Bind restricted RPC to all interfaces
rpc-restricted-bind-port=18089            # Bind restricted RPC on custom port to differentiate from default unrestricted RPC (18081)
no-igd=1                       # Disable UPnP port mapping

# ZMQ configuration
no-zmq=1

# Block known-malicious nodes from a DNSBL
enable-dns-blocklist=1


# Set download and upload limits, if desired
# limit-rate-up=128000 # 128000 kB/s == 125MB/s == 1GBit/s; a raise from default 2048 kB/s; contribute more to p2p network
# limit-rate-down=128000 # 128000 kB/s == 125MB/s == 1GBit/s; a raise from default 2048 kB/s; contribute more to p2p network" | sudo tee /mnt/hdd/monero/${prefix}monerod.conf
  fi
}

#Create monerod service file
create_monerod_service(){
  if [ ! -f "/etc/systemd/system/monerod.service" ];then
  echo "[Unit]
Description=Monero Full Node (Mainnet)
After=network.target

[Service]
# Process management
####################

Type=forking
PIDFile=/run/monero/monerod.pid
ExecStart=/usr/local/bin/monerod --config-file=/mnt/hdd/monero/monerod.conf --pidfile /run/monero/monerod.pid --detach
Restart=on-failure
RestartSec=30

# Directory creation and permissions
####################################

# Run as monero:monero
User=monero
Group=monero

# /run/monero
RuntimeDirectory=monero
RuntimeDirectoryMode=0710

# /var/lib/monero
StateDirectory=monero
StateDirectoryMode=0710

# /var/log/monero
LogsDirectory=monero
LogsDirectoryMode=0710

# /etc/monero
ConfigurationDirectory=monero
ConfigurationDirectoryMode=0710

# Hardening measures
####################

# Provide a private /tmp and /var/tmp.
PrivateTmp=true

# Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full

# Deny access to /home, /root and /run/user
ProtectHome=true

# Disallow the process and all of its children to gain
# new privileges through execve().
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/monerod.service
  fi
}

# add default value to raspi config if needed
if ! grep -Eq "^monero=" /mnt/hdd/raspiblitz.conf; then
  echo "monero=off" >> /mnt/hdd/raspiblitz.conf
fi

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ];then
  echo
  echo "Monero Tools"
  echo
  echo "Usage:"
  echo "bonus.monero.sh [on|off|status|menu]"
  echo
  echo "on - Install and activate Monero"
  echo "off - Deactivate and remove Monero"
  echo "status - Show status of Monero"
  echo "menu - Show Monero menu"
  echo
  echo "Example:"
  echo "monero.sh on"
  echo "monero.sh off"
  echo "monero.sh status"
  echo "monero.sh menu"
  echo
  exit 1
fi

#If input is install-from-build then install from build
if [ "$1" = "full-build" ]; then
  echo "*** Installing Monero ***"
  echo "This can take a while ... please be patient."
  echo "The installation will be done in the background."
  echo "When the installation is done you will see a message: 'OK - Monero is ready'"
  # Open port 18080 and 18089 if not already open
  sudo ufw allow 18080 comment 'Monero P2P'
  sudo ufw allow 18089 comment 'Monero RPC'
  # install monero for raspiblitz
  create_config_file
  create_monerod_service
  /home/admin/_cache.sh set monero on
  if id "monero" >/dev/null 2>&1; then
    echo "user exists"
  else
    # add monero user

    echo "user does not exist"
    sudo addgroup --system monero
    sudo adduser --system --home /home/monero --ingroup monero --disabled-login monero
    # add monero to hdd
    sudo mkdir -p /mnt/hdd/monero

    #create monero file
    sudo touch /mnt/hdd/monero/monerod.conf
    sudo chown -R monero:monero /mnt/hdd/monero
  fi
  sudo -u monero mkdir -p /home/monero/download-monero
  cd /home/monero/download-monero || exit 1
  # setting value in raspi blitz config
  sudo sed -i "s/^monero=.*/monero=on/g" /mnt/hdd/raspiblitz.conf
  # install monero for raspiblitz
  sudo apt update && sudo apt install -y build-essential cmake pkg-config libssl-dev libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libexpat1-dev libpgm-dev qttools5-dev-tools libhidapi-dev libusb-1.0-0-dev libprotobuf-dev protobuf-compiler libudev-dev libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev libboost-locale-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev libboost-system-dev libboost-thread-dev python3 ccache doxygen graphviz
  #Check if monero repo exists
  if [ -d "/home/monero/download-monero/monero" ]; then
    echo "Monero repo exists"
    cd monero || exit 1
    sudo -u monero git pull
    sudo -u monero git submodule update
    sudo -u monero git checkout release-v0.18
    sudo -u monero make -j4
    echo "OK - Monero is ready"
    exit 0
  fi
  sudo -u monero git clone --recursive https://github.com/monero-project/monero
  cd monero && sudo -u monero git submodule init && sudo -u monero git submodule update
  sudo -u monero git checkout release-v0.18
  sudo -u monero make -j4
  #remove all old monero files from /usr/local/bin
  sudo rm /usr/local/bin/monero*
  #move all monero files to /usr/local/bin
  sudo mv /home/monero/download-monero/monero/build/release/bin/* /usr/local/bin

  
  echo "OK - Monero is ready"
  exit 0
fi

if [ "$1" = "on" ]; then
  echo "*** Installing Monero ***"
  echo "This can take a while ... please be patient."
  echo "The installation will be done in the background."
  echo "When the installation is done you will see a message: 'OK - Monero is ready'"

  # Open port 18080 and 18089 if not already open
  # Port 18080 is needed for the node to work
  sudo ufw allow 18080 comment 'Monero P2P'
  # Port 18089 is not needed for the node to work, but it is needed for the wallet to work
  sudo ufw allow 18089 comment 'Monero RPC'
  sudo apt install yad
  # install monero for raspiblitz
  create_config_file
  create_monerod_service
  /home/admin/_cache.sh set monero on
  if id "monero" >/dev/null 2>&1; then
    echo "user exists"
    sudo rm -rf /home/monero/download-monero
  else
    # add monero user

    echo "user does not exist"
    sudo addgroup --system monero
    sudo adduser --system --home /home/monero --ingroup monero --disabled-login monero
    # add monero to hdd
    sudo mkdir -p /mnt/hdd/monero

    #create monero file
    sudo touch /mnt/hdd/monero/monerod.conf
    sudo chown -R monero:monero /mnt/hdd/monero
  fi
  sudo -u monero mkdir -p /home/monero/download-monero
  cd /home/monero/download-monero || exit 1

  # setting value in raspi blitz config
  sudo sed -i "s/^monero=.*/monero=on/g" /mnt/hdd/raspiblitz.conf


  # needed to check code signing
  binaryFatePGP="81AC 591F E9C4 B65C 5806 AFC3 F0AF 4D46 2A0B DF92"
  # receive signer key  
  # wget -O binaryfate.asc https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc
  if sudo -u monero wget -q -O binaryfate.asc https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc > /dev/null; then
      gpg --import binaryfate.asc
  else
    echo "# FAIL # Couldn't download binaryFates PGP pubkey"
    exit 1
  fi

  # # download signed binary sha256 hash sum file and check
  sudo -u monero wget https://www.getmonero.org/downloads/hashes.txt
  verifyResult=$(LANG=en_US.utf8; gpg --verify hashes.txt 2>&1)
  goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
  echo "goodSignature(${goodSignature})"
  correctKey=$(echo ${verifyResult} | grep "${binaryFatePGP}" -c)
  echo "correctKey(${correctKey})"
  if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
    echo
    echo "# BUILD FAILED --> PGP Verify not OK / signature(${goodSignature}) verify(${correctKey})"
    exit 1
  else
    echo
    echo "****************************************"
    echo "OK --> MONERO MANIFEST IS CORRECT"
    echo "****************************************"
    echo
  fi


  # moneroOSversion
  if [ "$(uname -m | grep -c 'arm')" -gt 0 ]; then
    moneroOSversion="arm-linux-gnueabihf"
  elif [ "$(uname -m | grep -c 'aarch64')" -gt 0 ]; then
    moneroOSversion="aarch64-linux-gnu"
  elif [ "$(uname -m | grep -c 'x86_64')" -gt 0 ]; then
    moneroOSversion="linux-x64"
    moneroFileVersion="x86_64-linux-gnu"
  fi

  echo
  echo "*** MONERO CORE v${moneroVersion} for ${moneroOSversion} ***"

  # download resources
  binaryName="monero-${moneroOSversion}-v${moneroVersion}.tar.bz2"
  if [ ! -f "./${binaryName}" ]; then
    if [ "${moneroOSversion}" == "linux-x64" ]; then
      sudo -u monero wget -O monero-${moneroOSversion}-v${moneroVersion}.tar.bz2 https://downloads.getmonero.org/cli/linux64
    fi
  fi
  if [ ! -f "./${binaryName}" ]; then
     echo "# FAIL # Could not download the Monero Binary"
     exit 1
  else

    # check binary checksum test
    echo "- checksum test"
    # get the sha256 value for the corresponding platform from signed hash sum file
    moneroSHA256=$(grep -i "${binaryName}" hashes.txt | cut -d " " -f1)
    binaryChecksum=$(sha256sum ${binaryName} | cut -d " " -f1)
    echo "Valid SHA256 checksum should be: ${moneroSHA256}"
    echo "Downloaded binary SHA256 checksum: ${binaryChecksum}"
    if [ "${binaryChecksum}" != "${moneroSHA256}" ]; then
      echo "# FAIL # Downloaded BITCOIN BINARY not matching SHA256 checksum: ${moneroSHA256}"
      rm -v ./${binaryName}
      exit 1
    else
      echo
      echo "********************************************"
      echo "OK --> Monero Core Binary Checksum Verified"
      echo "********************************************"
      echo
      sleep 10
      echo
    fi
  fi

  # install monero binary to /usr/local/bin
  echo "- install monero binary"
  sudo -u monero tar -xjf ${binaryName}
  sudo install -m 0755 -o monero -g monero -t /usr/local/bin/ monero-${moneroFileVersion}-v${moneroVersion}/*
  # sudo chown -R monero:monero /usr/local/bin/monero*
  sleep 3
  installed=$(sudo -u monero monerod --version | grep "${moneroVersion}" -c)
  if [ ${installed} -lt 1 ]; then
    echo
    echo "# BUILD FAILED --> Was not able to install monerod version(${moneroVersion})"
    exit 1
  fi
  if [ "$(alias | grep -c "alias monerolog")" -eq 0 ];then
    echo "alias monerolog=\"sudo tail -n 30 -f /mnt/hdd/monero/monerod.log\""  | sudo tee -a /home/admin/_aliases
  fi
  #may not be necessary
  sudo chown admin:admin /home/admin/_aliases

  if [ "${runBehindTor}" = "on" ]; then
    # make sure to keep in sync with internet.tor.sh script
    /home/admin/config.scripts/tor.onion-service.sh monero 18089 18089
    echo "Tor Enabled"
  fi

  echo "- Monero install OK"
  echo
  echo "********************************************"
  echo "OK --> Monero Core v${moneroVersion} is installed"
  echo "********************************************"
  echo
  echo "You can start monerod with:"
  echo "sudo systemctl start monerod"
  echo
  echo "You can check the status with:"
  echo "sudo systemctl status monerod"
  echo
  echo "You can stop monerod with:"
  echo "sudo systemctl stop monerod"
  echo
  echo "You can check the logs with:"
  echo "sudo journalctl -u monerod -b"
  echo
  echo "You can check the logs with:"
  echo "sudo tail -n 30 -f /mnt/hdd/monero/monerod.log"
  echo
  echo "You can check the logs with:"
  echo "monerolog"

  exit 0
fi

if [ "$1" = "off" ]; then
  # setting value in raspi blitz config
  if [ -z "$(ls -A /home/monero)" ]; then
    echo "# Monero tools are not installed."
  else
    echo "# *** Removing Monero ***"
    STATUS="$(systemctl is-active monerod.service)"
    /home/admin/_cache.sh set monero off
    if [ "${STATUS}" = "active" ]; then
        echo "Stopping monerod....."
        sudo systemctl stop monerod
    fi
    # delete user and home directory
    sudo userdel -rf monero
    #remove alias _aliases
    # Hidden Service if Tor is active
    if [ "${runBehindTor}" = "on" ]; then
      echo "Tor Enabled"
      # make sure to keep in sync with internet.tor.sh script
      /home/admin/config.scripts/tor.onion-service.sh off monero
    fi
    #remove monero from raspiblitz config
    sudo sed -i "s/^monero=.*/monero=off/g" /mnt/hdd/raspiblitz.conf
    #remove firewall rules
    sudo ufw deny 18080/tcp
    sudo ufw deny 18089/tcp
    #remove monerod.conf
    sudo rm /mnt/hdd/monero/${prefix}monerod.conf
    sudo rm /mnt/hdd/monero/${prefix}monerod.log
    #remove monerod.service
    sudo rm /etc/systemd/system/monerod.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo "# Monero tools have been removed."
  fi
  exit 0
fi

if [ "$1" = "menu" ]; then
  # BASIC MENU INFO
  echo "Starting Menu"
  WIDTH=64
  BACKTITLE="RaspiBlitz"
  TITLE=" Monero Options (Mainnet) "
  MENU="Choose one of the following options:"
  OPTIONS=()

  OPTIONS+=(STATUS "Check the status of your node")
  OPTIONS+=(LOG "View the log of your node")
  OPTIONS+=(TOGGLE  "Restart Monero")
  OPTIONS+=(REINDEX "Reindex Monero")
  OPTIONS+=(UPDATE "Update Monero")
  OPTIONS+=(OFF "Remove Monero")

  CHOICE_HEIGHT=$(("${#OPTIONS[@]}/2+1"))
  HEIGHT=$((CHOICE_HEIGHT+6))
  CHOICE=$(dialog --clear \
                  --backtitle "$BACKTITLE" \
                  --title "$TITLE" \
                  --ok-label "Select" \
                  --cancel-label "Main menu" \
                  --menu "$MENU" \
                  $HEIGHT $WIDTH $CHOICE_HEIGHT \
                  "${OPTIONS[@]}" \
                  2>&1 >/dev/tty)

  case $CHOICE in
    STATUS)
        clear
        echo "*** Returning status ***"
        # get status
        echo "# Collecting status info ... (please wait)"
        STATUS="$(systemctl is-active monerod.service)"
        if [ "${STATUS}" = "active" ]; then
          localIP=$(hostname -I | awk '{print $1}')
          toraddress=$(sudo cat /mnt/hdd/tor/monero/hostname 2>/dev/null)
          fingerprint=$(openssl x509 -in /mnt/hdd/app-data/nginx/tls.cert -fingerprint -noout | cut -d"=" -f2)
          # IP + Domain
          # Check monerod sync status and return the percentage of the blockchain that is synced
          syncStatus=$(monerod sync_info | grep "%" | awk '{print $5}'|  grep -o '[0-9]\+')
          currBlockheight=$(monerod sync_info | grep "target:"| awk '{print $2}'|  grep -o '[0-9]\+')
          targetBlockheight=$(monerod sync_info | grep "target:"| awk '{print $4}'|  grep -o '[0-9]\+')
          monerodVersion=$(monerod --version)
          #number of peers
          numInbound=$(monerod status | grep "Height:" | awk '{print $13}' | grep -o '[0-9]\+' | head -n 1)
          numOutbound=$(monerod status | grep "Height:" | awk '{print $13}' | grep -o '[0-9]\+' | tail -n 1)
          if [ "${runBehindTor}" = "on" ] && [ ${#toraddress} -gt 0 ]; then
            # TOR
            /home/admin/config.scripts/blitz.display.sh qr "${toraddress}"
            whiptail --title "Monero Daemon" --msgbox "Block Height ${currBlockheight}/${targetBlockheight} - ${syncStatus}% Synced\n${numInbound} Inbound/${numOutbound} Outbound Peers\n
Connect your wallet to the Monero network with:\nhttps://${localIP}:18089\n
Hidden Service address for TOR Browser (QR see LCD):\n${toraddress}\n
SHA1 Fingerprint: ${fingerprint}\n
        " 17 67
            /home/admin/config.scripts/blitz.display.sh hide
          else
            #set whiptail guage to sync status
            whiptail --title " Monero Daemon" --msgbox "Block Height ${currBlockheight}/${targetBlockheight} -  ${syncStatus}% Synced\n${numInbound} Inbound/${numOutbound} Outbound Peers\n
Connect your node to the Monero network with:\nhttps://${localIP}:18089\n
Activate TOR to access your node from outside your local network.\n
SHA1 Fingerprint: ${fingerprint}\n
        " 17 54 
          fi
        else
          echo "# Monerod is not running"
          echo "# Last 30 lines of the monerod.log file:"
          sudo tail -n 30 -f /mnt/hdd/monero/monerod.log
        fi        
        echo "Press ENTER to return to main menu."
        read key
        ;;
    TOGGLE)
        clear
        # Restart monerod and check logs for errors
        echo "*** Restarting Monero ***"
        echo "# Stopping monerod"
        sudo systemctl stop monerod
        echo "# Starting monerod"
        sudo systemctl start monerod
        echo "# Watching logs for 15 seconds then returning to main menu"
        end=$((SECONDS+15))
        while [ $SECONDS -lt $end ]; do
          sudo tail -n 1 -f /mnt/hdd/monero/monerod.log
        done
        # return to main menu
        echo "Press ENTER to return to main menu."
        read key
        ;;
    UPDATE)
        /home/admin/config.scripts/bonus.monero.sh update
        ;;
    REINDEX)
        /home/admin/config.scripts/bonus.monero.sh reindex
        ;;
    LOG)
        clear
        echo "*** Monero Log ***"
        echo "# Last 30 lines of the monerod.log file:"
        # Follow the log file and ctrl+c to exit
        sudo tail -n 30 -f /mnt/hdd/monero/monerod.log
        echo "Press ENTER to return to main menu."
        read key 
        ;;
    OFF)
        /home/admin/config.scripts/bonus.monero.sh off
        ;;
  esac
  exit 0
fi

# Reindex monerod
if [ "$1" = "reindex" ]; then
  echo "# Reindexing monerod"
  sudo systemctl stop monerod
  sudo rm /mnt/hdd/monero/monerod.log
  sudo rm /mnt/hdd/monero/monerod.pid
  sudo rm /mnt/hdd/monero/monerod.bin
  sudo rm /mnt/hdd/monero/monerod.db
  sudo rm /mnt/hdd/monero/monerod.db.lock
  sudo rm /mnt/hdd/monero/monerod.db-shm
  sudo rm /mnt/hdd/monero/monerod.db-wal
  sudo systemctl start monerod
  echo "# Reindexing monerod complete"
  exit 0
fi

# status
if [ "$1" = "status" ]; then
  if [ "${monero}" = "on" ]; then
    echo "configured=1"
    # get status
    STATUS="$(systemctl is-active monerod.service)"
    if [ "${STATUS}" = "active" ]; then
      echo "status=1"
    else
      echo "status=0"
    fi
  else
    echo "configured=0"
  fi
  exit 0
fi

echo "# Abort from $1"

exit 1

