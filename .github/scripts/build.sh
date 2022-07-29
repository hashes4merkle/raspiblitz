#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update -y && sudo apt-get install packer -y

echo -e "Installing GO..."
wget https://go.dev/dl/go1.18.4.linux-arm64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.18.4.linux-arm64.tar.gz
sudo rm -rf go1.18.4.linux-arm64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Install Packer Arm Plugin
echo -e "\nInstalling Packer Arm Plugin..."
git clone https://github.com/mkaczanowski/packer-builder-arm
cd packer-builder-arm
go mod download
go build

# Move json file to packer folder
echo -e "\nMoving json file to packer folder..."
if [ -f 2022-01-28-raspios-bullseye-arm64-full.zip ]
then
    echo "File exists."
else
    wget https://downloads.raspberrypi.org/raspios_full_arm64/images/raspios_full_arm64-2022-01-28/2022-01-28-raspios-bullseye-arm64-full.zip
fi
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/raspiblitz.json 
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/packages.config
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/post-install.sh
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/post-install-bitcoin.sh
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/post-install-lnd.sh
wget https://raw.githubusercontent.com/hashes4merkle/raspiblitz/pipelines/.github/scripts/post-install-cln.sh
# Build packer
echo -e "\nBuilding packer image..."
docker run --rm --privileged -v /dev:/dev -v ${PWD}:/build mkaczanowski/packer-builder-arm build raspiblitz.json
echo -e "\nBuild complete." 
echo -e "\nUploading image to release..."
# Upload image to release  
# curl -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/octet-stream" --data-binary @raspiblitz.img.gz https://uploads.github.com/repos/hashes4merkle/raspiblitz/releases/46320270/assets?name=raspiblitz.img.gz
