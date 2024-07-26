#!/bin/bash
#
# Copied from https://github.com/daboynb/linux_scripts/blob/main/upgrade_ubuntu_versions.sh

# Hold function
hold(){
    sudo apt upgrade -y > apt_output.txt

    last_line=$(cat apt_output.txt | grep -o '[0-9]' | tail -n2 apt_output.txt | sed '2d')

    numbers=$(echo "$last_line" | grep -o '[0-9]\+')

    pkg=$(echo $numbers | awk '{print $NF}')

    # Check if packages are kept back
    if [[ $pkg -gt 0 ]]; then
        echo "There are packages that need to be updated."
        sudo apt install aptitude -y
        sudo aptitude safe-upgrade -y
        rm apt_output.txt
    fi
}

# System update function
upgrade (){
    sudo apt update
    sudo apt install -f -y
    sudo apt -o APT::Get::Always-Include-Phased-Updates=true upgrade -y
    sudo apt dist-upgrade -y
    sudo apt autoremove --purge -y

    # Check for hold packages twice
    hold > /dev/null 2>&1
    if hold | grep -q "There are packages that need to be updated."; then
        echo "There are packages that need to be updated."
        exit
    fi

    # Start the upgrade process
    sudo do-release-upgrade
}

# Check if sudo apt update ran succesfully
apt_update(){
    output=$(sudo apt update 2>&1)
    if echo $output | grep -q 'Err\|W:'; then
        echo "sudo apt update failed"
        echo "$output" | grep -E 'Err|W:'
    else
        echo "sudo apt update successful"

    fi
}

echo "Which release should 'do-release-upgrade' check?"
echo "1. Non-LTS"
echo "2. LTS"
read -p "Enter your choice (1 or 2): " choice

if [ "$choice" == "1" ]; then
    sudo sed -i 's/Prompt=.*/Prompt=normal/g' /etc/update-manager/release-upgrades
elif [ "$choice" == "2" ]; then
    sudo sed -i 's/Prompt=.*/Prompt=lts/g' /etc/update-manager/release-upgrades
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Bypass "An upgrade from 'xxx' to 'xxx' is not supported with this tool" error
sudo sed -i 's/continue/pass/g' /usr/lib/python3/dist-packages/UpdateManager/Core/MetaRelease.py

# Disable all the external repos
sudo bash -c 'for i in /etc/apt/sources.list.d/*.list; do mv ${i} ${i}.disabled; done'

# Grep codename
codename=$(awk '/UBUNTU_CODENAME=/' /etc/os-release | sed 's/UBUNTU_CODENAME=//' | sed 's/[.]0/./')

# Set default sources.list
current_release="deb http://archive.ubuntu.com/ubuntu/ $codename main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu $codename-security main universe restricted multiverse
deb http://archive.ubuntu.com/ubuntu/ $codename-updates main universe restricted multiverse"

sudo echo "$current_release" | sudo tee "/etc/apt/sources.list"

# Check the result of the apt_update funciton
check_output=$(apt_update)
if echo "$check_output" | grep -q "sudo apt update successful"; then
    echo "sudo apt update successful"
else
    # Edit sources.list
    old_release="deb http://old-releases.ubuntu.com/ubuntu/ $codename main restricted universe multiverse
    deb http://old-releases.ubuntu.com/ubuntu/ $codename-updates main restricted universe multiverse
    deb http://old-releases.ubuntu.com/ubuntu/ $codename-security main restricted universe multiverse"
    sudo echo "$old_release" | sudo tee /etc/apt/sources.list

    # Check again
    check_output=$(apt_update)
    if echo "$check_output" | grep -q "sudo apt update successful"; then
        echo "sudo apt update successful"
    else
        echo "Failed to run sudo apt update"
        exit
    fi
fi

upgrade
