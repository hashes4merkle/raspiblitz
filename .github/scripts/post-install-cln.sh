#!/bin/bash

#cln
CLVERSION=v0.10.2

PGPsigner="cdecker"
PGPpubkeyLink="https://raw.githubusercontent.com/ElementsProject/lightning/master/contrib/keys/${PGPsigner}.txt"
PGPpubkeyFingerprint="A26D6D9FE088ED58"

  
  echo "# *** INSTALL C-LIGHTNING ${CLVERSION} BINARY ***"
  echo "# only binary install to system"
  echo "# no configuration, no systemd service"

git clone https://github.com/ElementsProject/lightning.git /home/bitcoin/lightning
cd /home/bitcoin/lightning || exit 1
echo
echo "- Reset to version $CLVERSION"
git reset --hard $CLVERSION

/home/admin/config.scripts/blitz.git-verify.sh \
  "${PGPsigner}" "${PGPpubkeyLink}" "${PGPpubkeyFingerprint}" "${CLVERSION}" || exit 1


pip3 install mrkd==0.2.0
pip3 install mistune==0.8.4
# for pylightning
echo "- Install from the requirements.txt"
pip3 install --user mrkd==0.2.0
pip3 install --user mistune==0.8.4
pip3 install --user -r requirements.txt


echo "- Configuring EXPERIMENTAL_FEATURES enabled"
echo
./configure --enable-experimental-features
echo
echo "- Building C-lightning from source"
echo
make
echo
echo "- Install to /usr/local/bin/"
make install || exit 1

installed=$(lightning-cli --version)
if [ ${#installed} -eq 0 ]; then
  echo
  echo "!!! BUILD FAILED --> Was not able to install C-lightning"
  exit 1
fi

correctVersion=$(echo "${installed}" | grep -c "${CLVERSION:1}")
if [ "${correctVersion}" -eq 0 ]; then
  echo
  echo "!!! BUILD FAILED --> installed C-lightning is not version ${CLVERSION}"
  lightning-cli --version
  exit 1
fi
echo
echo "- OK the installation of C-lightning v${installed} is successful"
