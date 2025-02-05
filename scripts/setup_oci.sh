#!/bin/bash

# Install git and python3
sudo apt-get update
sudo apt-get install -y git python3-venv python3-pip

# Check Python version
py=python3
version=$($py --version 2>&1 | awk '{print $2}')
echo "Python version in use : $version"
version_numeric=$(echo $version | awk -F. '{printf "%d%02d%02d\n", $1, $2, $3}')
if [ "$version_numeric" -lt 30800 ]; then
    echo "Python version is < 3.8 please update python before install"
    exit 1
fi

# Check venv module
if [ ! "$($py -m venv -h 2>/dev/null | grep -i 'usage:')" ]; then
    echo "venv module is not installed."
    echo "please install $py-venv according to your system"
    exit 1
fi

# Create and activate virtual environment
mkdir -p /home/goad/.goad
$py -m venv /home/goad/.goad/.venv
source /home/goad/.goad/.venv/bin/activate

# Install ansible with Azure extras (includes Windows support) and pywinrm
pip install --upgrade pip
pip install 'ansible[azure]' pywinrm

# Determine which requirements file to use based on Python version
if [ "$version_numeric" -lt 31100 ]; then
    requirement_file="requirements.yml"
else
    requirement_file="requirements_311.yml"
fi

# Install the required ansible libraries
cd /home/goad/GOAD/ansible && ansible-galaxy install -r $requirement_file && cd -

# set color
sudo sed -i '/force_color_prompt=yes/s/^#//g' /home/*/.bashrc
sudo sed -i '/force_color_prompt=yes/s/^#//g' /root/.bashrc
