param(
  [Parameter(Mandatory = $true)]
  [string]$ManagementAgentZipUrl,

  [Parameter(Mandatory = $false)]
  [string]$ResponseFileUrl = "",

  [Parameter(Mandatory = $false)]
  [string]$ManagementAgentInstallKey = "",

  [Parameter(Mandatory = $false)]
  [string]$CredentialWalletPassword = "",

  [Parameter(Mandatory = $false)]
  [string]$ResponseFileLocalPath = "C:\Agents\agent.rsp"
)

$WorkRoot        = Join-Path $env:TEMP "oci-mgmt-agent-setup"
$ZipPath         = Join-Path $WorkRoot "agent.zip"
$ExtractPath     = Join-Path $WorkRoot "extract"
$CorrettoMsiUrl  = "https://corretto.aws/downloads/latest/amazon-corretto-8-x64-windows-jdk.msi"
$CorrettoMsiPath = Join-Path $WorkRoot "corretto8.msi"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Error "Run this script as Administrator."
  exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ExtractPath | Out-Null
$agentsDir = Split-Path $ResponseFileLocalPath -Parent
if (-not (Test-Path $agentsDir)) {
  New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
}

function Download-File {
  param([string]$Uri, [string]$OutFile)
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
  } catch {
    Write-Error "Failed to download $Uri -> $OutFile"
    throw
  }
}

function Expand-Zip {
  param([string]$Zip, [string]$Dest)
  try {
    Expand-Archive -Path $Zip -DestinationPath $Dest -Force
  } catch {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Dest)
  }
}

function Find-Installer {
  param([string]$Root)
  $patterns = @("installer.bat", "setup.bat", "install*.bat", "installer*.bat")
  foreach ($pat in $patterns) {
    $hit = Get-ChildItem -Path $Root -Recurse -Filter $pat -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  return $null
}

function Get-Java8HomePath {
  $paths = @(
    "C:\Program Files\Amazon Corretto",
    "C:\Program Files\Java",
    "C:\Program Files (x86)\Java"
  ) | Where-Object { Test-Path $_ }

  foreach ($base in $paths) {
    $cand = Get-ChildItem -Path $base -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^jdk1\.8\.0' -or $_.Name -match 'corretto.*8' } |
            Sort-Object Name -Descending |
            Select-Object -First 1
    if ($cand -and (Test-Path (Join-Path $cand.FullName 'bin\java.exe'))) {
      return $cand.FullName
    }
  }

  foreach ($key in @(
    'HKLM:\SOFTWARE\JavaSoft\JDK\1.8',
    'HKLM:\SOFTWARE\Amazon Corretto\JDK\1.8'
  )) {
    if (Test-Path $key) {
      try {
        $jh = (Get-ItemProperty -Path $key -ErrorAction Stop).JavaHome
        if ($jh -and (Test-Path (Join-Path $jh 'bin\java.exe'))) {
          return $jh
        }
      } catch {
      }
    }
  }
  return $null
}

function Ensure-Java8 {
  $javaHomePath = Get-Java8HomePath
  if (-not $javaHomePath) {
    Write-Host "Installing Amazon Corretto JDK 8..."
    Download-File -Uri $CorrettoMsiUrl -OutFile $CorrettoMsiPath
    $args = "/i `"$CorrettoMsiPath`" /qn"
    $p = Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "Corretto 8 installation failed with exit code $($p.ExitCode)" }
    Start-Sleep -Seconds 3
    $javaHomePath = Get-Java8HomePath
    if (-not $javaHomePath) { throw "Could not determine JAVA_HOME for JDK 8 after install." }
  } else {
    Write-Host "JDK 8 already present at $javaHomePath"
  }

  [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHomePath, "Machine")
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  if ($machinePath -notmatch [Regex]::Escape("$javaHomePath\bin")) {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$javaHomePath\bin", "Machine")
  }
  $env:JAVA_HOME = $javaHomePath
  if ($env:Path -notmatch [Regex]::Escape("$javaHomePath\bin")) {
    $env:Path = "$env:Path;$javaHomePath\bin"
  }
  Write-Host "JAVA_HOME set to $javaHomePath"
}

$svc = Get-Service -Name "mgmt_agent" -ErrorAction SilentlyContinue
if ($svc) {
  Write-Host "OCI Management Agent already installed, skipping."
  exit 0
}

Write-Host "Ensuring Java 8 is available..."
Ensure-Java8

Write-Host "Downloading OCI Management Agent ZIP..."
Download-File -Uri $ManagementAgentZipUrl -OutFile $ZipPath

if (-not [string]::IsNullOrWhiteSpace($ManagementAgentInstallKey)) {
  Write-Host "Generating response file from install key..."
  $rspContent = "ManagementAgentInstallKey = $ManagementAgentInstallKey`r`n"
  if (-not [string]::IsNullOrWhiteSpace($CredentialWalletPassword)) {
    $rspContent += "CredentialWalletPassword = $CredentialWalletPassword`r`n"
  }
  $rspContent += "Service.plugin.logan.download=true`r`n"
  $rspContent += "Service.plugin.opsiHost.download=true`r`n"
  $rspContent += "Service.plugin.appmgmt.download=true`r`n"
  Set-Content -Path $ResponseFileLocalPath -Value $rspContent -Encoding ASCII
} elseif (-not [string]::IsNullOrWhiteSpace($ResponseFileUrl)) {
  Write-Host "Downloading RSP file to $ResponseFileLocalPath ..."
  Download-File -Uri $ResponseFileUrl -OutFile $ResponseFileLocalPath
} else {
  throw "Provide either -ManagementAgentInstallKey or -ResponseFileUrl."
}

Write-Host "Extracting package..."
Expand-Zip -Zip $ZipPath -Dest $ExtractPath

$installer = Find-Installer -Root $ExtractPath
if (-not $installer) {
  Write-Error "Installer not found in extracted package."
  Get-ChildItem -Path $ExtractPath -Recurse | Format-Table FullName
  exit 1
}

Write-Host "Using installer: $installer"
Write-Host "Running installer with RSP as sole argument..."
$p = Start-Process -FilePath $installer -ArgumentList @($ResponseFileLocalPath) -Wait -PassThru
if ($p.ExitCode -ne 0) {
  throw "Installer returned exit code $($p.ExitCode)"
}

Write-Host "OCI Management Agent installation finished."
exit 0
