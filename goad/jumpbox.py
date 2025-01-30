from goad.command.cmd_factory import CommandFactory
from goad.log import Log
from goad.utils import *
from goad.goadpath import GoadPath


class JumpBox:

    def __init__(self, instance, creation=False):
        self.lab_name = instance.lab_name
        self.instance_id = instance.instance_id
        self.instance_path = instance.instance_path
        self.provider = instance.provider
        self.username = 'ubuntu' if self.provider.provider_name == 'oci' else 'goad'
        self.command = CommandFactory.get_command()
        
        # Get SSH key path
        if self.provider.provider_name == 'oci':
            self.ssh_key = os.path.join(GoadPath.get_template_path('oci'), 'ssh_keys', 'ubuntu-jumpbox.pem')
            self.remote_goad_path = '/home/goad/GOAD'
            self.setup_script = os.path.join(GoadPath.get_template_path('oci'), 'setup_goad_user.sh')
            self.goad_user_setup = False
        else:
            self.ssh_key = os.path.join(self.instance_path, 'ssh_keys', 'ubuntu-jumpbox.pem')
            self.remote_goad_path = '~/GOAD'

        if not creation:
            self.ip = self.provider.get_jumpbox_ip(instance.ip_range)
            if not os.path.isfile(self.ssh_key):
                Log.error(f'Missing ssh file at {self.ssh_key}')
            if self.ip is None:
                Log.error('Missing ip for JumpBox remote connection')
        else:
            self.ip = None

    def provision(self):
        script_name = self.provider.jumpbox_setup_script
        script_file = GoadPath.get_script_file(script_name)
        if not os.path.isfile(script_file):
            Log.error(f'script file: {script_file} not found !')
            return None
        self.run_script(script_file)
        
        # For OCI, set up the goad user after initial provisioning
        if self.provider.provider_name == 'oci':
            self.setup_goad_user()

    def setup_goad_user(self):
        """Set up goad user on OCI jumpbox"""
        if not os.path.isfile(self.setup_script):
            Log.error(f'Missing setup script at {self.setup_script}')
            return None
        self.run_script(self.setup_script)
        # Switch to goad user for future operations
        self.username = 'goad'
        self.goad_user_setup = True

    def get_jumpbox_key(self, creation=False):
        return self.ssh_key

    def ssh(self):
        ssh_cmd = f'ssh -o StrictHostKeyChecking=no -i "{self.ssh_key}" {self.username}@{self.ip}'
        self.command.run_shell(ssh_cmd, project_path)

    def ssh_proxy(self, port):
        ssh_cmd = f'ssh -o StrictHostKeyChecking=no -D {port} -i "{self.ssh_key}" {self.username}@{self.ip}'
        self.command.run_shell(ssh_cmd, project_path)

    def run_script(self, script):
        ssh_cmd = f'ssh -o StrictHostKeyChecking=no -i "{self.ssh_key}" {self.username}@{self.ip} "bash -s" < "{script}"'
        self.command.run_shell(ssh_cmd, project_path)

    def sync_sources(self):
        """
        rsync ansible folder to the jumpbox ip
        :return:
        """
        source = GoadPath.get_project_path()
        if Utils.is_valid_ipv4(self.ip):
            # For OCI, set up goad user if not already done
            if self.provider.provider_name == 'oci' and not self.goad_user_setup:
                self.setup_goad_user()

            destination = f'{self.username}@{self.ip}:{self.remote_goad_path}/'
            self.command.rsync(source, destination, self.ssh_key)

            # workspace
            source = self.instance_path
            destination = f'{self.username}@{self.ip}:{self.remote_goad_path}/workspace/'
            self.command.rsync(source, destination, self.ssh_key, False)
        else:
            Log.error('Can not sync source jumpbox ip is invalid')

    def run_command(self, command, path):
        # For OCI, set up goad user if not already done
        if self.provider.provider_name == 'oci' and not self.goad_user_setup:
            self.setup_goad_user()

        # Convert relative GOAD paths to absolute paths for OCI
        if self.provider.provider_name == 'oci':
            if path.startswith('~/GOAD/'):
                path = path.replace('~/GOAD/', '/home/goad/GOAD/')
            elif not path.startswith('/'):
                path = f'/home/goad/GOAD/{path}'
            
            # Update ansible-playbook path for OCI
            if 'ansible-playbook' in command:
                command = command.replace('ansible-playbook', '/home/goad/.venv/bin/ansible-playbook')
                # Remove any references to .local/bin since we're using venv
                command = command.replace('/home/goad/.local/bin/', '')

        ssh_cmd = f'ssh -t -o StrictHostKeyChecking=no -i "{self.ssh_key}" {self.username}@{self.ip} "cd \"{path}\" && {command}"'
        result = self.command.run_command(ssh_cmd, project_path)
        return result
