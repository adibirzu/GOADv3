resource "oci_core_instance" "windows_instance" {
  for_each = {
    kingslanding = { hostname = "WIN-KL", display_name = "Windows KingsLanding", private_ip_address = "192.168.56.10", image_ocid = var.windows2019_image_ocid }
    winterfell  = { hostname = "WIN-WF", display_name = "Windows Winterfell", private_ip_address = "192.168.56.11", image_ocid = var.windows2019_image_ocid }
    meereen     = { hostname = "WIN-MR", display_name = "Windows Meereen", private_ip_address = "192.168.56.12", image_ocid = var.windows2016_image_ocid }
    braavos     = { hostname = "WIN-BR", display_name = "Windows Braavos", private_ip_address = "192.168.56.23", image_ocid = var.windows2016_image_ocid }
    castelblack = { hostname = "WIN-CB", display_name = "Windows CastelBlack", private_ip_address = "192.168.56.22", image_ocid = var.windows2019_image_ocid }
  }
  
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = each.value.display_name
  
  shape = "VM.Standard.E4.Flex"
  shape_config {
    ocpus                     = 2
    memory_in_gbs             = 32
    baseline_ocpu_utilization = "BASELINE_1_1"
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.private_subnet.id
    display_name             = "${each.key}-vnic"
    assign_public_ip         = false
    hostname_label           = each.value.hostname
    assign_private_dns_record = true
    private_ip               = each.value.private_ip_address
    nsg_ids                  = []
  }

  source_details {
    source_type             = "image"
    source_id               = each.value.image_ocid
    boot_volume_size_in_gbs = 256
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }

  extended_metadata = {
    user_data = base64encode(<<-EOT
<powershell>
# Variables
$adminUsername = "ansible"
$adminPassword = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force

# Create ansible user
New-LocalUser $adminUsername -Password $adminPassword -FullName $adminUsername -Description "Ansible admin user"
Add-LocalGroupMember -Group "Administrators" -Member $adminUsername

# Enable WinRM
winrm quickconfig -q
winrm set winrm/config/service/auth @{Basic="true"}
winrm set winrm/config/service @{AllowUnencrypted="true"}
winrm set winrm/config/service @{EnableCompatibilityHttpsListener="true"}
winrm set winrm/config/service @{EnableCompatibilityHttpListener="true"}
$cert = New-SelfSignedCertificate -DnsName $(hostname) -CertStoreLocation Cert:\LocalMachine\My
winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=$(hostname); CertificateThumbprint=$($cert.Thumbprint)}
Set-Service -Name winrm -StartupType Automatic
Start-Service -Name winrm

# Enable basic authentication and unencrypted traffic for WinRM
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Configure WinRM firewall exception
New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM (HTTP-In)" -Protocol TCP -LocalPort 5985 -Action Allow -Enabled True
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "WinRM (HTTPS-In)" -Protocol TCP -LocalPort 5986 -Action Allow -Enabled True

# Set the TLS 1.2 protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Install NuGet provider and update PowerShellGet
Install-PackageProvider -Name NuGet -Force -Confirm:$false
Update-Module -Name PowerShellGet -Force -AllowClobber -Confirm:$false
# Restart Computer
shutdown /r /t 10 /f

</powershell>
<persist>true</persist>
EOT
    )
  }

  timeouts {
    create = "60m"
  }

  lifecycle {
    ignore_changes = [
      defined_tags
    ]
  }
}