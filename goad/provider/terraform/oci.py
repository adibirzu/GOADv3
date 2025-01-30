import json
import os
import platform
import shutil
import subprocess
import shlex
import sys
from pathlib import Path
from goad.provider.terraform.terraform import TerraformProvider
from goad.goadpath import GoadPath
from goad.log import Log
from goad.utils import (
    OCI, PROVISIONING_REMOTE, CREATED, PROVIDED, READY,
    Utils, os, random, string
)


class OCIProvider(TerraformProvider):
    provider_name = OCI
    default_provisioner = PROVISIONING_REMOTE
    allowed_provisioners = [PROVISIONING_REMOTE]
    update_ip_range = True

    def __init__(self, lab_name, config):
        super().__init__(lab_name)
        self.lab_name = lab_name
        self.compartment_ocid = None
        self.config = config
        self.jumpbox_setup_script = 'setup_oci.sh'
        self._ssh_key_path = None
        self.instance_id = None

    def set_instance_path(self, provider_instance_path):
        super().set_instance_path(provider_instance_path)
        # Extract instance_id from path
        self.instance_id = os.path.basename(os.path.dirname(provider_instance_path))

    def get_terraform_vars(self):
        """Get terraform variables including SSH public key"""
        vars = {}
        try:
            # Read SSH public key from workspace
            ssh_pub_key_path = os.path.join(self.path, 'ssh_keys', 'ubuntu-jumpbox.pub')
            if os.path.exists(ssh_pub_key_path):
                with open(ssh_pub_key_path, 'r') as f:
                    vars['ssh_public_key'] = f.read().strip()
        except Exception as e:
            Log.error(f'Error reading SSH public key: {str(e)}')
        return vars

    def run_terraform(self, args, path):
        """Run terraform with variables"""
        result = None
        try:
            # Get terraform variables
            vars = self.get_terraform_vars()
            
            # Add variables to command
            command = [self.terraform_bin]
            command.extend(args)
            for key, value in vars.items():
                command.extend(['-var', f'{key}={value}'])

            Log.info('CWD: ' + Utils.get_relative_path(str(path)))
            Log.cmd(' '.join(command))
            result = subprocess.run(command, cwd=path, stderr=sys.stderr, stdout=sys.stdout)
        except subprocess.CalledProcessError as e:
            Log.error(f"An error occurred while running the command: {e}")
        return result.returncode == 0

    def run_command(self, command, path=None):
        """Run a command with proper path handling for SSH keys"""
        try:
            # Get the jumpbox key path and ensure it exists
            key_path = os.path.join(GoadPath.get_instance_path(self.instance_id), 'ssh_keys', 'ubuntu-jumpbox.pem')
            if not os.path.exists(key_path):
                Log.error(f'SSH key not found at {key_path}')
                return False

            # Create a symbolic link in /tmp for the SSH key to avoid path issues
            tmp_key = '/tmp/goad_jumpbox.pem'
            try:
                if os.path.exists(tmp_key):
                    os.remove(tmp_key)
                os.symlink(key_path, tmp_key)
                os.chmod(tmp_key, 0o600)
            except Exception as e:
                Log.error(f'Failed to create symlink: {str(e)}')
                return False

            # Get jumpbox IP
            jumpbox_ip = self.get_jumpbox_ip()
            if not jumpbox_ip:
                Log.error('Failed to get jumpbox IP')
                return False

            # Create the SSH command using the temporary key path
            ssh_command = [
                'ssh',
                '-t',
                '-o', 'StrictHostKeyChecking=no',
                '-i', tmp_key,
                f'ubuntu@{jumpbox_ip}',  # Changed from goad to ubuntu
                command
            ]

            Log.info(f'Running command: {" ".join(ssh_command)}')
            
            # Run the command
            result = subprocess.run(
                ssh_command,
                check=False,
                cwd=path if path else os.getcwd(),
                text=True,
                capture_output=True
            )

            # Clean up the temporary symlink
            try:
                os.remove(tmp_key)
            except:
                pass

            if result.returncode != 0:
                Log.error(f'Command failed with return code: {result.returncode}')
                if result.stderr:
                    Log.error(f'Error output: {result.stderr}')
                return False

            return True

        except Exception as e:
            Log.error(f'Error executing command: {str(e)}')
            return False

    def get_jumpbox_ip(self, ip_range=''):
        """Get the jumpbox IP address"""
        try:
            state_file = os.path.join(self.path, 'terraform.tfstate')
            if not os.path.exists(state_file):
                Log.error('Terraform state file not found')
                return None

            with open(state_file, 'r') as f:
                tfstate = json.load(f)
                for resource in tfstate.get('resources', []):
                    if (resource.get('type') == 'oci_core_instance' and 
                        resource.get('name') == 'jumpbox' and 
                        resource.get('instances')):
                        return resource['instances'][0]['attributes'].get('public_ip')

            Log.error('Jumpbox IP not found in terraform state')
            return None

        except Exception as e:
            Log.error(f'Error getting jumpbox IP: {str(e)}')
            return None

    def prepare_ssh_key(self):
        """Ensure SSH key is properly set up"""
        instance_path = GoadPath.get_instance_path(self.instance_id)
        ssh_dir = os.path.join(instance_path, 'ssh_keys')
        key_path = os.path.join(ssh_dir, 'ubuntu-jumpbox.pem')

        try:
            # Create SSH directory with proper permissions
            os.makedirs(ssh_dir, mode=0o700, exist_ok=True)

            # Generate SSH key pair if it doesn't exist
            if not os.path.exists(key_path):
                Log.info('Generating new SSH key pair')
                subprocess.run([
                    'ssh-keygen',
                    '-t', 'rsa',
                    '-b', '2048',
                    '-f', key_path,
                    '-N', ''  # Empty passphrase
                ], check=True)

            # Set proper permissions on private key
            os.chmod(key_path, 0o600)
            return True
        except Exception as e:
            Log.error(f'Error preparing SSH key: {str(e)}')
            return False

    def get_ip_range(self):
        """Get the IP range from the VCN CIDR"""
        try:
            state_file = os.path.join(self.path, 'terraform.tfstate')
            if os.path.exists(state_file):
                with open(state_file) as f:
                    tfstate = json.load(f)
                    for resource in tfstate.get('resources', []):
                        if resource.get('type') == 'oci_core_vcn':
                            cidr_block = resource.get('instances', [{}])[0].get('attributes', {}).get('cidr_block')
                            if cidr_block:
                                return '.'.join(cidr_block.split('.')[:3])
            return '192.168.56'  # Default if not found
        except Exception as e:
            Log.error(f'Error getting IP range: {str(e)}')
            return '192.168.56'

    def set_compartment_ocid(self, compartment_name):
        """Set the compartment OCID based on the compartment name"""
        # For now, we'll use the name as is since we're creating the compartment
        self.compartment_ocid = compartment_name
        Log.info(f'Setting compartment identifier to: {self.compartment_ocid}')

    def get_compartment_ocid(self):
        """Get the current compartment OCID"""
        return self.compartment_ocid

    def check(self):
        """Verify OCI provider requirements"""
        Log.info('Check OCI requirements')
        
        # Check if terraform is installed
        terraform_path = shutil.which('terraform')
        if not terraform_path:
            Log.error('Terraform not found in PATH')
            Log.info('Please install Terraform: https://developer.hashicorp.com/terraform/install')
            return False

        # Check terraform version
        terraform_version = self._get_terraform_version()
        if terraform_version:
            Log.info(f'Terraform version: {terraform_version}')
        else:
            Log.error('Unable to determine Terraform version')
            return False

        # Check if OCI CLI is installed 
        oci_path = shutil.which('oci')
        if not oci_path:
            Log.error('OCI CLI not found in PATH')
            Log.info('Please install OCI CLI: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm')
            return False

        # Verify OCI configuration
        if not self._check_oci_config():
            return False

        Log.success('OCI requirements ok')
        return True
    
    def _get_os_info(self):
        """Get OS information"""
        system = platform.system().lower()
        is_wsl = 'microsoft' in platform.uname().release.lower()
        
        if is_wsl:
            return 'wsl'
        elif system == 'darwin':
            return 'macos'
        elif system == 'linux':
            # Detect Linux distribution
            try:
                with open('/etc/os-release') as f:
                    lines = f.readlines()
                    os_info = dict(line.strip().split('=', 1) for line in lines if '=' in line)
                    id_like = os_info.get('ID_LIKE', os_info.get('ID', '')).strip('"').lower()
                    
                    if 'debian' in id_like or 'ubuntu' in id_like:
                        return 'debian'
                    elif 'fedora' in id_like or 'rhel' in id_like:
                        return 'fedora'
                    else:
                        return 'linux'
            except:
                return 'linux'
        elif system == 'windows':
            return 'windows'
        else:
            return 'unknown'

    def _ensure_terraform(self):
        """Ensure Terraform is installed"""
        terraform_path = shutil.which('terraform')
        if terraform_path:
            version = self._get_terraform_version()
            Log.info(f'Terraform version {version} is already installed')
            return True

        Log.info('Terraform not found, attempting to install...')
        os_type = self._get_os_info()

        try:
            if os_type == 'macos':
                if shutil.which('brew'):
                    self._run_command('brew install terraform')
                else:
                    Log.error('Homebrew not found. Please install Homebrew first:')
                    Log.info('/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
                    return False
            
            elif os_type in ['debian', 'ubuntu', 'wsl']:
                self._run_command('sudo apt-get update')
                self._run_command('sudo apt-get install -y gnupg software-properties-common curl')
                self._run_command('curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -')
                self._run_command('sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"')
                self._run_command('sudo apt-get update')
                self._run_command('sudo apt-get install -y terraform')
            
            elif os_type == 'fedora':
                self._run_command('sudo dnf install -y dnf-plugins-core')
                self._run_command('sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo')
                self._run_command('sudo dnf install -y terraform')
            
            elif os_type == 'windows':
                if shutil.which('choco'):
                    self._run_command('choco install terraform -y')
                else:
                    Log.error('Chocolatey not found. Please install Chocolatey first:')
                    Log.info('Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString(\'https://community.chocolatey.org/install.ps1\'))')
                    return False
            
            else:
                Log.error('Automatic installation not supported for your OS')
                Log.info('Please install Terraform manually: https://developer.hashicorp.com/terraform/install')
                return False

            # Verify installation
            terraform_path = shutil.which('terraform')
            if terraform_path:
                version = self._get_terraform_version()
                Log.success(f'Successfully installed Terraform version {version}')
                return True
            else:
                Log.error('Terraform installation failed')
                return False

        except Exception as e:
            Log.error(f'Error installing Terraform: {str(e)}')
            return False

    def _ensure_oci_cli(self):
        """Ensure OCI CLI is installed"""
        oci_path = shutil.which('oci')
        if oci_path:
            try:
                version = subprocess.check_output(['oci', '--version']).decode().strip()
                Log.info(f'OCI CLI version {version} is already installed')
                return True
            except:
                pass

        Log.info('OCI CLI not found, attempting to install...')
        os_type = self._get_os_info()

        try:
            if os_type == 'macos':
                if shutil.which('brew'):
                    self._run_command('brew install oci-cli')
                else:
                    Log.error('Homebrew not found. Please install Homebrew first')
                    return False
            
            elif os_type in ['debian', 'ubuntu', 'wsl']:
                self._run_command('sudo apt-get update')
                self._run_command('sudo apt-get install -y python3-pip')
                self._run_command('pip3 install oci-cli')
            
            elif os_type == 'fedora':
                self._run_command('sudo dnf install -y python3-pip')
                self._run_command('pip3 install oci-cli')
            
            elif os_type == 'windows':
                if shutil.which('choco'):
                    self._run_command('choco install oci-cli -y')
                else:
                    Log.error('Chocolatey not found. Please install Chocolatey first')
                    return False
            
            else:
                Log.error('Automatic installation not supported for your OS')
                Log.info('Please install OCI CLI manually: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm')
                return False

            # Verify installation
            oci_path = shutil.which('oci')
            if oci_path:
                try:
                    version = subprocess.check_output(['oci', '--version']).decode().strip()
                    Log.success(f'Successfully installed OCI CLI version {version}')
                    return True
                except:
                    Log.error('OCI CLI installation verification failed')
                    return False
            else:
                Log.error('OCI CLI installation failed')
                return False

        except Exception as e:
            Log.error(f'Error installing OCI CLI: {str(e)}')
            return False

    def _check_oci_config(self):
        """Verify OCI configuration exists"""
        required_configs = [
            ('oci', 'tenancy_ocid'),
            ('oci', 'user_ocid'),
            ('oci', 'fingerprint'),
            ('oci', 'private_key_path'),
            ('oci', 'region')
        ]

        for section, key in required_configs:
            value = self.config.get_value(section, key)
            if not value:
                Log.error(f'Missing required OCI configuration: [{section}] {key}')
                Log.info('Please update your ~/.goad/goad.ini file with the required OCI configuration')
                return False
            
            # Check if private key file exists
            if key == 'private_key_path':
                if not os.path.exists(os.path.expanduser(value)):
                    Log.error(f'OCI private key file not found: {value}')
                    return False

        return True

    def _get_terraform_version(self):
        """Get Terraform version"""
        try:
            result = subprocess.check_output(['terraform', 'version']).decode()
            if result:
                return result.split('\n')[0]
            return None
        except Exception as e:
            Log.error(f'Error getting Terraform version: {str(e)}')
            return None

    def destroy(self):
        """Override destroy to run terraform init first"""
        self.command.run_terraform(['init'], self.path)
        return super().destroy()

    def get_jumpbox_ssh_key(self):
        """Get the path to the jumpbox SSH private key"""
        if not self._ssh_key_path:
            key_path = os.path.join(self.path, 'ssh_keys', 'ubuntu-jumpbox.pem')
            if os.path.exists(key_path):
                self._ssh_key_path = key_path
                # Ensure correct permissions
                os.chmod(key_path, 0o600)
            else:
                Log.error(f'SSH key not found at {key_path}')
                return None
        return self._ssh_key_path
