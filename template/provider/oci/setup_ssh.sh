#!/bin/bash
set -e

# Create SSH keys directory
mkdir -p ssh_keys

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "ubuntu@jumpbox" -f ssh_keys/ubuntu-jumpbox.pem -N ""

# Rename public key
mv ssh_keys/ubuntu-jumpbox.pem.pub ssh_keys/ubuntu-jumpbox.pub

# Set correct permissions
chmod 600 ssh_keys/ubuntu-jumpbox.pem
chmod 644 ssh_keys/ubuntu-jumpbox.pub

# Verify the keys
echo "Private key permissions:"
ls -l ssh_keys/ubuntu-jumpbox.pem
echo "Public key permissions:"
ls -l ssh_keys/ubuntu-jumpbox.pub
echo "Public key content:"
cat ssh_keys/ubuntu-jumpbox.pub
