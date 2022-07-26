#!/bin/bash

#lnd
lndVersion="0.14.2-beta"
PGPauthor="guggero"
PGPpkeys="https://keybase.io/guggero/pgp_keys.asc"
PGPcheck="F4FC70F07310028424EFC20A8E4256593F177720"
lndOSversion="arm64"
network="bitcoin"

# ###########
# # LIGHTNING #
# ###########
# REFERENCE: /home/admin/config.scripts/lnd.install.sh install

echo "# *** INSTALL LND ${lndVersion} BINARY ***"
echo "# only binary install to system"
echo "# no configuration, no systemd service"

wget -N https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/manifest-v${lndVersion}.txt -P home/admin/download

# # check if checksums are signed by lnd dev team

wget -N https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/manifest-${PGPauthor}-v${lndVersion}.sig -P /home/admin/download 
wget --no-check-certificate -O /home/admin/download/pgp_keys.asc ${PGPpkeys} 
echo "Importing keys"
gpg --import --import-options show-only /home/admin/download/pgp_keys.asc

fingerprint=$(gpg --show-keys "/home/admin/download/pgp_keys.asc" 2>/dev/null | grep "${PGPcheck}" -c)
if [ ${fingerprint} -lt 1 ]; then
  echo ""
  echo "!!! BUILD WARNING --> LND PGP author not as expected"
  echo "Should contain PGP: ${PGPcheck}"
  echo "PRESS ENTER to TAKE THE RISK if you think all is OK"
fi
gpg --import /home/admin/download/pgp_keys.asc
sleep 3
echo "verify key"
gpg --verify /home/admin/download/manifest-${PGPauthor}-v${lndVersion}.sig /home/admin/download/manifest-v${lndVersion}.txt 2>&1
verifyResult="$(gpg --verify /home/admin/download/manifest-${PGPauthor}-v${lndVersion}.sig /home/admin/download/manifest-v${lndVersion}.txt 2>&1)"
goodSignature="$(echo ${verifyResult} | grep 'Good signature' -c)"
echo "goodSignature(${goodSignature})"
correctKey="$(echo ${verifyResult} | tr -d " \t\n\r" | grep "${PGPcheck}" -c)"
echo "correctKey(${correctKey})"
if [ ${correctKey} -lt 1 ] || [ ${goodSignature} -lt 1 ]; then
  echo
  echo "!!! BUILD FAILED --> LND PGP Verify not OK / signature(${goodSignature}) verify(${correctKey})"
  exit 1
else
  echo
  echo "********************************************"
  echo "OK --> THE LND MANIFEST SIGNATURE IS CORRECT"
  echo "********************************************"
  echo
fi



# get the lndSHA256 for the corresponding platform from manifest file
if [ "$(uname -m | grep -c 'arm')" -gt 0 ]; then
  lndOSversion="armv7"
  lndSHA256=$(grep -i "linux-$lndOSversion" /home/admin/download/manifest-v$lndVersion.txt | cut -d " " -f1)
elif [ "$(uname -m | grep -c 'aarch64')" -gt 0 ]; then
  lndOSversion="arm64"
  lndSHA256=$(grep -i "linux-$lndOSversion" /home/admin/download/manifest-v$lndVersion.txt | cut -d " " -f1)
elif [ "$(uname -m | grep -c 'x86_64')" -gt 0 ]; then
  lndOSversion="amd64"
  lndSHA256=$(grep -i "linux-$lndOSversion" /home/admin/download/manifest-v$lndVersion.txt | cut -d " " -f1)
fi

echo "*** LND v${lndVersion} for ${lndOSversion} ***"
echo "SHA256 hash: $lndSHA256"
echo

# get LND binary
binaryName="lnd-linux-${lndOSversion}-v${lndVersion}.tar.gz"
if [ ! -f "/home/admin/download/${binaryName}" ]; then
  lndDownloadUrl="https://github.com/lightningnetwork/lnd/releases/download/v${lndVersion}/${binaryName}"
  echo "- downloading lnd binary --> ${lndDownloadUrl}"
  wget ${lndDownloadUrl} -P /home/admin/download
  echo "- download done"
else
  echo "- using existing lnd binary"
fi

# check binary was not manipulated (checksum test)
echo "- checksum test"
binaryChecksum=$(sha256sum /home/admin/download/${binaryName} | cut -d " " -f1)
echo "Valid SHA256 checksum(s) should be: ${lndSHA256}"
echo "Downloaded binary SHA256 checksum: ${binaryChecksum}"
checksumCorrect=$(echo "${lndSHA256}" | grep -c "${binaryChecksum}")
if [ "${checksumCorrect}" != "1" ]; then
  echo "!!! FAIL !!! Downloaded LND BINARY not matching SHA256 checksum in manifest: ${lndSHA256}"
  rm -v /home/admin/download/${binaryName}
  exit 1
else
  echo
  echo "**************************************************"
  echo "OK --> THE VERIFIED LND BINARY CHECKSUM IS CORRECT"
  echo "**************************************************"
  echo
  sleep 10
fi

# install
echo "- install LND binary"
tar -xzf /home/admin/download/${binaryName} -C /home/admin/download
install -m 0755 -o root -g root -t /usr/local/bin /home/admin/download/lnd-linux-${lndOSversion}-v${lndVersion}/*
sleep 3
installed=$(lnd --version)
if [ ${#installed} -eq 0 ]; then
  echo
  echo "!!! BUILD FAILED --> Was not able to install LND"
  exit 1
fi

correctVersion=$(lnd --version | grep -c "${lndVersion}")
if [ ${correctVersion} -eq 0 ]; then
  echo ""
  echo "!!! BUILD FAILED --> installed LND is not version ${lndVersion}"
  lnd --version
  exit 1
fi
chown -R admin /home/admin
echo "- OK install of LND done"

