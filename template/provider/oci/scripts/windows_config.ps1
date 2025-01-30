<powershell>
# Set Administrator password
$adminPassword = ConvertTo-SecureString "YourSecurePassword123!" -AsPlainText -Force
$adminUser = [ADSI]"WinNT://./Administrator,user"
$adminUser.SetPassword("YourSecurePassword123!")
$adminUser.SetInfo()

# Enable WinRM
Write-Output "Configuring WinRM..."
Set-ExecutionPolicy Bypass -Force

# Delete any existing WinRM listeners
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse

# Create self-signed certificate
$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $env:COMPUTERNAME
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force

# Configure WinRM service
winrm quickconfig -q
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{CredSSP="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'

# Increase memory limit for WinRM
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024

# Configure WinRM HTTPS listener
winrm set winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$env:computername`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

# Configure timeouts and limits
Set-Item WSMan:\localhost\MaxTimeoutms 1800000
Set-Item WSMan:\localhost\Service\MaxConcurrentOperationsPerUser 100
Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxMemoryPerShellMB 1024
Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxConcurrentUsers 100
Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxProcessesPerShell 100
Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxShellsPerUser 100

# Configure firewall rules
Write-Output "Configuring firewall rules..."
Remove-NetFirewallRule -Name "WinRM-HTTP" -ErrorAction SilentlyContinue
Remove-NetFirewallRule -Name "WinRM-HTTPS" -ErrorAction SilentlyContinue

New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "Windows Remote Management (HTTP-In)" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow
New-NetFirewallRule -Name "WinRM-HTTPS" -DisplayName "Windows Remote Management (HTTPS-In)" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow

# Enable PSRemoting
Enable-PSRemoting -Force
Set-Service WinRM -StartupType Automatic
Restart-Service WinRM

# Set TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider and PowerShell modules
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name PowerShellGet -Force -AllowClobber
Install-Module -Name ComputerManagementDsc -Force
Install-Module -Name xNetworking -Force

Write-Output "WinRM configuration complete."
</powershell>
