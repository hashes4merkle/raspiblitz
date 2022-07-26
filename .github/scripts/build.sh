#!/bin/bash -e

# Install packer
echo -e "\nInstalling packer..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update -y && apt-get install packer -y

# Install Packer Arm Plugin
echo -e "\nInstalling Packer Arm Plugin..."
wget https://github.com/mkaczanowski/packer-builder-arm 
cd packer-builder-arm
go mod download
go build

# Move json file to packer folder
echo -e "\nMoving json file to packer folder..."

# Build packer
echo -e "\nBuilding packer image..."
packer build boards/odroid-u3/archlinuxarm.json