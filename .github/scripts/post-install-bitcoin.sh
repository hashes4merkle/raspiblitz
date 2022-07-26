#!/bin/bash
#bitcoin
binaryName="bitcoin-22.0-aarch64-linux-gnu.tar.gz"
bitcoinVersion="22.0"
laanwjPGP="71A3 B167 3540 5025 D447 E8F2 7481 0B01 2346 C9A6"
bitcoinOSversion="aarch64-linux-gnu"
# ###########
# # BITCOIN #
# ###########
# echo
# /home/admin/config.scripts/bitcoin.install.sh install || exit 1

echo -e "\n*** BITCOIN INSTALL ***"
rm -rf /home/admin/download
mkdir /home/admin/download

# receive signer key
if ! gpg -q --keyserver hkp://keyserver.ubuntu.com --recv-key "71A3 B167 3540 5025 D447 E8F2 7481 0B01 2346 C9A6" 
then
  echo "!!! BUILD FAILED !!! Couldn't download Wladimir J. van der Laan's PGP pubkey"
  exit 1
fi

# download signed binary sha256 hash sum file
wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS -P /home/admin/download 

# download signed binary sha256 hash sum file and check
wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/SHA256SUMS.asc -P /home/admin/download 

verifyResult=$(gpg --verify /home/admin/download/SHA256SUMS.asc 2>&1)
goodSignature=$(echo ${verifyResult} | grep 'Good signature' -c)
echo "goodSignature(${goodSignature})"
correctKey=$(echo ${verifyResult} | grep "${laanwjPGP}" -c)
echo "correctKey(${correctKey})"
if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
  echo
  echo "!!! BUILD FAILED --> PGP Verify not OK / signature(${goodSignature}) verify(${correctKey})"
  exit 1
else
  echo
  echo "****************************************"
  echo "OK --> BITCOIN MANIFEST IS CORRECT"
  echo "****************************************"
  echo
fi

echo
echo "*** BITCOIN CORE v${bitcoinVersion} for ${bitcoinOSversion} ***"


# download resources
binaryName="bitcoin-${bitcoinVersion}-${bitcoinOSversion}.tar.gz"
if [ ! -f "/home/admin/download/${binaryName}" ]; then
   wget https://bitcoincore.org/bin/bitcoin-core-${bitcoinVersion}/${binaryName} -P /home/admin/download 
fi
if [ ! -f "/home/admin/download/${binaryName}" ]; then
   echo "!!! FAIL !!! Could not download the BITCOIN BINARY"
   exit 1
else

  # check binary checksum test
  echo "- checksum test"
  # get the sha256 value for the corresponding platform from signed hash sum file
  bitcoinSHA256=$(grep -i "${binaryName}" /home/admin/download/SHA256SUMS | cut -d " " -f1)
  binaryChecksum=$(sha256sum /home/admin/download/${binaryName} | cut -d " " -f1)
  echo "Valid SHA256 checksum should be: ${bitcoinSHA256}"
  echo "Downloaded binary SHA256 checksum: ${binaryChecksum}"
  if [ "${binaryChecksum}" != "${bitcoinSHA256}" ]; then
    echo "!!! FAIL !!! Downloaded BITCOIN BINARY not matching SHA256 checksum: ${bitcoinSHA256}"
    rm -v /home/admin/download/${binaryName}
    exit 1
  else
    echo
    echo "********************************************"
    echo "OK --> VERIFIED BITCOIN CORE BINARY CHECKSUM"
    echo "********************************************"
    echo
    sleep 10
    echo
  fi
fi

# install
tar -xvf /home/admin/download/${binaryName} -C /home/admin/download
install -m 0755 -o root -g root -t /usr/local/bin/ /home/admin/download/bitcoin-${bitcoinVersion}/bin/*
sleep 3
installed=$(bitcoind --version | grep "${bitcoinVersion}" -c)
if [ ${installed} -lt 1 ]; then
  echo
  echo "!!! BUILD FAILED --> Was not able to install bitcoind version(${bitcoinVersion})"
  exit 1
fi
if [ "$(alias | grep -c "alias bitcoinlog")" -eq 0 ];then 
  echo "alias bitcoinlog=\"sudo tail -n 30 -f /mnt/hdd/bitcoin/debug.log\""  | tee -a /home/admin/_aliases
fi
chown -R admin:admin /home/admin
ls -la
bitcoind --version
echo "- Bitcoin install OK"
