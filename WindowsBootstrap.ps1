
${CONSUL_ADDR_LIST} = "[]"
${CONSUL_SERVICE_USER_NAME} = "${env:serviceUser}"
${CONSUL_SERVICE_USER_PASS} = "${env:servicePass}"
${NOMAD_SERVICE_USER_NAME} = ${CONSUL_SERVICE_USER_NAME}
${NOMAD_SERVICE_USER_PASS} = ${CONSUL_SERVICE_USER_PASS}
${VAULT_SERVICE_USER_NAME} = ${CONSUL_SERVICE_USER_NAME}
${VAULT_SERVICE_USER_PASS} = ${CONSUL_SERVICE_USER_PASS}

${NOMAD_VERSION} = "0.8.4"
${CONSUL_VERSION} = "1.0.2"
${VAULT_VERSION} = "0.10.3"

$global:IP = $null     #  This gets set once the function exists. Just here for documentation sake.

function Unzip($zipFile) {
  If ($PSVersionTable.PSVersion.Major -gt 4) {
    Expand-Archive -path $zipFile
  } else {
    DownloadUnzip
    ## Expand-Archive creates a folder of the same name as the archive file
    ## and unzips the archive there.  This preserves that behavior
    $extractPath = [io.path]::GetFileNameWithoutExtension($zipFile)
    md $extractPath
    unzip.exe -qq $zipFile -d $extractPath
  }  
}

function DownloadUnzip {
  MaybeDownloadFile unzip.exe http://www.willus.com/archive/zip64/unzip.exe C:\Windows\System32\unzip.exe
}

function MaybeDownloadFile ($exeName, $url, $expectedDestination) {
  if (!(Test-Path $expectedDestination)) {
    DownloadFile $exeName $url $expectedDestination
  }  
}

function DownloadFile ($exeName, $url, $expectedDestination) {
    Write-Host "Installing $exeName..." -ForegroundColor Green
    wget.exe -q --no-check-certificate $url
    Copy $exeName $expectedDestination
    erase $exeName
}

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}

function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green    
}

function Enable-RemoteDesktop {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"  
    Write-Host "Remote Desktop Connections have been enabled." -ForegroundColor Green
}

function Get-DefaultIPAddress {
  $defaultIface=Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "ifIndex"
  Get-NetIPAddress -InterfaceIndex $defaultIface -AddressFamily IPV4 | Select-Object -ExpandProperty "IPAddress"
}

$global:IP = Get-DefaultIPAddress

function Install-wget {
  Write-Host "Installing wget..." -ForegroundColor Green
  if (!(Test-Path "c:\windows\system32\wget.exe")) {
    $client = New-Object System.Net.WebClient;
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
    $client.DownloadFile("https://eternallybored.org/misc/wget/1.19.4/64/wget.exe","c:\windows\system32\wget.exe")
  }
}

function Install-nssm {
  Write-Host "Installing nssm..." -ForegroundColor Green
  wget.exe -q --no-check-certificate https://nssm.cc/release/nssm-2.24.zip
  Unzip .\nssm-2.24.zip
  Copy .\nssm-2.24\nssm-2.24\win64\nssm.exe C:\Windows\System32
  erase .\nssm-2.24\ -Recurse
  erase .\nssm-2.24.zip
}

function Generate-ConsulConfig {
@"
  {
    `"bind_addr`": `"${global:IP}`",
    `"client_addr`": `"0.0.0.0`",
    `"datacenter`": `"dc1`",
    `"data_dir`": `"C:\\Consul\\data`",
    `"log_level`": `"DEBUG`",
    `"node_name`": "${env:computername}`",
    `"watches`": [ ],
    `"bootstrap_expect`": 1,
    `"server`": true
  }
"@ | Out-File -Encoding ASCII -FilePath C:\Consul\config\consul.json
}

function Generate-ConsulLabConfig {
@"
  {
    `"retry_join`": ${CONSUL_ADDR_LIST},
    `"bind_addr`": `"${global:IP}`",
    `"client_addr`": `"0.0.0.0`",
    `"datacenter`": `"dc1`",
    `"data_dir`": `"C:\\Consul\\lab\\data`",
    `"log_level`": `"DEBUG`",
    `"node_name`": "${env:computername}`",
    `"watches`": [ ]
  }
"@ | Out-File -Encoding ASCII -FilePath C:\Consul\lab\config\consul.json
}


function MaybeRemoveSymlink ($fileName) {
  if (Test-Path $fileName) {
    Remove-Item -path $fileName
  }  
}


function Install-consul {
  Write-Host "Installing Consul..." -ForegroundColor Green
  mkdir C:\Consul\bin -ErrorAction SilentlyContinue;
  mkdir c:\Consul\data -ErrorAction SilentlyContinue;
  mkdir c:\Consul\logs -ErrorAction SilentlyContinue;
  mkdir c:\Consul\config -ErrorAction SilentlyContinue;
  wget.exe -q --no-check-certificate  https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_windows_amd64.zip
  Unzip .\consul_${CONSUL_VERSION}_windows_amd64.zip
  copy .\consul_${CONSUL_VERSION}_windows_amd64\consul.exe C:\Consul\bin\consul_${CONSUL_VERSION}.exe
  erase .\consul_${CONSUL_VERSION}_windows_amd64.zip
  erase .\consul_${CONSUL_VERSION}_windows_amd64 -Recurse
  
  MaybeRemoveSymlink C:\Consul\bin\consul.exe
  
  New-Item -Path C:\Consul\bin\consul.exe -ItemType SymbolicLink -Value C:\Consul\bin\consul_${CONSUL_VERSION}.exe
  
  Write-Host "   Creating Consul Service..." -ForegroundColor Green
  nssm install Consul C:\Consul\bin\consul.exe agent --config-dir="C:\\Consul\\config"
  nssm set Consul AppDirectory C:\Consul
  nssm set Consul Description Hashicorp Consul
  nssm set Consul Start SERVICE_AUTO_START
  nssm set Consul ObjectName $CONSUL_SERVICE_USER_NAME $CONSUL_SERVICE_USER_PASS
  nssm set Consul AppStdout C:\Consul\logs\consul.log
  nssm set Consul AppStderr C:\Consul\logs\consul.log
  nssm set Consul AppRotateFiles 1

  Write-Host "   Creating Consul Lab Service..." -ForegroundColor Green
  mkdir c:\Consul\lab -ErrorAction SilentlyContinue;
  mkdir c:\Consul\lab\data -ErrorAction SilentlyContinue;
  mkdir c:\Consul\lab\logs -ErrorAction SilentlyContinue;
  mkdir c:\Consul\lab\config -ErrorAction SilentlyContinue;
  nssm install Consul-Lab C:\Consul\bin\consul.exe agent --config="C:\\Consul\\lab\\config"
  nssm set Consul-Lab AppDirectory C:\Consul\Lab
  nssm set Consul-Lab Description Hashicorp Consul - Lab Agent
  nssm set Consul-Lab Start SERVICE_AUTO_START
  nssm set Consul-Lab ObjectName ${CONSUL_SERVICE_USER_NAME} ${CONSUL_SERVICE_USER_PASS}
  nssm set Consul-Lab AppStdout C:\Consul\lab\logs\consul.log
  nssm set Consul-Lab AppStderr C:\Consul\lab\logs\consul.log
  nssm set Consul-Lab AppRotateFiles 1

  Write-Host "   Adding Consul to Path..." -ForegroundColor Green
  $path = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", $path + "C:\Consul\bin;", "User")
}

function Generate-NomadConfig {
@"
  datacenter = `"dc1`"
  data_dir = `"C:\\Nomad\\data`"
  bind_addr = `"$global:IP`"
  client {
    options {
      `"driver.raw_exec.enable`" = `"1`"
    }
    enabled = true
  }
  server {
    enabled = true
    bootstrap_expect = 1
  }
"@ | Out-File -Encoding ASCII -FilePath C:\Nomad\config\nomad.hcl
}

function Generate-NomadLabConfig {
@"
  datacenter = `"dc1`"
  data_dir = `"C:\\Nomad\\lab\\data`"
  bind_addr = `"$global:IP`"
  client {
    options {
      `"driver.raw_exec.enable`" = `"1`"
    }
    enabled = true
  }
"@ | Out-File -Encoding ASCII -FilePath C:\Nomad\lab\config\nomad.hcl
}

function Install-nomad {
  Write-Host "Installing Nomad..." -ForegroundColor Green
  mkdir c:\Nomad\bin -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\data -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\logs -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\config -ErrorAction SilentlyContinue;
  wget.exe -q --no-check-certificate https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_windows_amd64.zip
  Unzip .\nomad_${NOMAD_VERSION}_windows_amd64.zip
  copy .\nomad_${NOMAD_VERSION}_windows_amd64\nomad.exe C:\Nomad\bin\nomad_${NOMAD_VERSION}.exe
  erase .\nomad_${NOMAD_VERSION}_windows_amd64.zip
  erase .\nomad_${NOMAD_VERSION}_windows_amd64 -Recurse
  
  MaybeRemoveSymlink C:\Nomad\bin\nomad.exe
  
  New-Item -Path C:\Nomad\bin\nomad.exe -ItemType SymbolicLink -Value C:\Nomad\bin\nomad_${NOMAD_VERSION}.exe
  Write-Host "   Creating Nomad Service..." -ForegroundColor Green
  nssm install Nomad C:\Nomad\bin\nomad.exe agent --config="C:\\Nomad\\config"
  nssm set Nomad AppDirectory C:\Nomad
  nssm set Nomad Description Hashicorp Nomad
  nssm set Nomad DependOnService Consul
  nssm set Nomad Start SERVICE_AUTO_START
  nssm set Nomad ObjectName ${NOMAD_SERVICE_USER_NAME} ${NOMAD_SERVICE_USER_PASS}
  nssm set Nomad AppStdout C:\Nomad\logs\nomad.log
  nssm set Nomad AppStderr C:\Nomad\logs\nomad.log
  nssm set Nomad AppRotateFiles 1

  Write-Host "   Creating Nomad Lab Service..." -ForegroundColor Green
  mkdir c:\Nomad\lab -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\lab\data -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\lab\logs -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\lab\config -ErrorAction SilentlyContinue;
  nssm install Nomad-Lab C:\Nomad\bin\nomad.exe agent --config="C:\\Nomad\\lab\\config"
  nssm set Nomad-Lab AppDirectory C:\Nomad\Lab
  nssm set Nomad-Lab Description Hashicorp Nomad - Lab Agent
  nssm set Nomad-Lab Start SERVICE_DEMAND_START
  nssm set Nomad-Lab ObjectName ${NOMAD_SERVICE_USER_NAME} ${NOMAD_SERVICE_USER_PASS}
  nssm set Nomad-Lab AppStdout C:\Nomad\lab\logs\nomad.log
  nssm set Nomad-Lab AppStderr C:\Nomad\lab\logs\nomad.log
  nssm set Nomad-Lab AppRotateFiles 1

  Write-Host "   Adding Nomad to Path..." -ForegroundColor Green
  $path = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", $path + "C:\Nomad\bin;", "User")
  [System.Environment]::SetEnvironmentVariable("NOMAD_ADDR", "http://${global:IP}:4646", "User")
}

function Generate-VaultConfig {
@"
  storage "consul" {
    address = "127.0.0.1:8500"
    path    = "vault/"
  }

  listener "tcp" {
    address     = "0.0.0.0:8200"
    tls_disable = 1
  }

  ui=true
  cluster_name="vault_dc1"
"@ | Out-File -Encoding ASCII -FilePath C:\Vault\config\vault.hcl
}

function Install-vault {
  Write-Host "Installing Vault..." -ForegroundColor Green
  mkdir C:\Vault\bin -ErrorAction SilentlyContinue;
  mkdir c:\Vault\data -ErrorAction SilentlyContinue;
  mkdir c:\Vault\logs -ErrorAction SilentlyContinue;
  mkdir c:\Vault\config -ErrorAction SilentlyContinue;
  wget.exe -q --no-check-certificate  https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_windows_amd64.zip
  Unzip .\vault_${VAULT_VERSION}_windows_amd64.zip
  copy .\vault_${VAULT_VERSION}_windows_amd64\vault.exe C:\Vault\bin\vault_${VAULT_VERSION}.exe
  erase .\vault_${VAULT_VERSION}_windows_amd64.zip
  erase .\vault_${VAULT_VERSION}_windows_amd64 -Recurse
  
  MaybeRemoveSymlink C:\Vault\bin\vault.exe
  
  New-Item -Path C:\Vault\bin\vault.exe -ItemType SymbolicLink -Value C:\Vault\bin\vault_${VAULT_VERSION}.exe
  Write-Host "   Creating Vault Service..." -ForegroundColor Green
  nssm install Vault C:\Vault\bin\vault.exe agent --config-dir="C:\\Vault\\config"
  nssm set Vault AppDirectory C:\Vault
  nssm set Vault Description Hashicorp Vault
  nssm set Vault DependOnService Consul
  nssm set Vault Start SERVICE_AUTO_START
  nssm set Vault ObjectName $VAULT_SERVICE_USER_NAME $VAULT_SERVICE_USER_PASS
  nssm set Vault AppStdout C:\Vault\logs\vault.log
  nssm set Vault AppStderr C:\Vault\logs\vault.log
  nssm set Vault AppRotateFiles 1

  Write-Host "   Adding Vault to Path..." -ForegroundColor Green
  $path = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", $path + "C:\Vault\bin;", "User")
}

function Set-VirtualTerminalLevel {
  # This allows the Command Prompt window to properly render
  # the ANSI control sequences for the colors and to not leave
  # poop on the screen
  reg add "HKEY_CURRENT_USER\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
}

function Install-Docker {
  Write-Host "Installing Docker...  (this will reboot the node)" -ForegroundColor Green
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
  Install-Module -Name DockerMsftProvider -Force
  Unregister-PackageSource -ProviderName DockerMsftProvider -Name DockerDefault -Erroraction Ignore
  Register-PackageSource -ProviderName DockerMsftProvider -Name Docker -Location https://download.docker.com/components/engine/windows-server/index.json
  Install-Package -Name docker -ProviderName DockerMsftProvider -Source Docker -Force
  Write-Host "Rebooting the node..." -ForegroundColor Yellow
  Restart-Computer -Force
}

function Install-Sublime {
  Write-Host "Installing Sublime Text 3..." -ForegroundColor Green
  wget.exe -q --no-check-certificate https://download.sublimetext.com/Sublime%20Text%20Build%203176%20x64%20Setup.exe
  Start-Process -FilePath '.\Sublime Text Build 3176 x64 Setup.exe' -ArgumentList "/SILENT" -NoNewWindow -Wait
  erase ".\Sublime Text Build 3176 x64 Setup.exe"
}

function Install-Chrome {
  Write-Host "Installing Google Chrome..." -ForegroundColor Green
  wget.exe -q --no-check-certificate https://download.sublimetext.com/Sublime%20Text%20Build%203176%20x64%20Setup.exe
  Start-Process -FilePath '.\Sublime Text Build 3176 x64 Setup.exe' -ArgumentList "/SILENT" -NoNewWindow -Wait
  erase ".\Sublime Text Build 3176 x64 Setup.exe"
}

clear

Disable-InternetExplorerESC
Enable-RemoteDesktop 
Install-wget
Install-nssm
Install-consul
Generate-ConsulConfig
Install-nomad
Generate-NomadConfig
Generate-NomadLabConfig
Install-vault
Generate-VaultConfig
Set-VirtualTerminalLevel

### I have Install-docker commented out because I need to
### change this to download Docker CE and install the MSI.
### The current implementation will work, it just loads the
### Windows container implementation

# Install-docker
# install hyper-v


### Things to (optionally) add:
# Google Chrome
## Sublime Text 3
# https://download.sublimetext.com/Sublime%20Text%20Build%203176%20x64%20Setup.exe

# Git
# Golang
# GnuTools
# Vim


### $env:PATH="${env:PATH}C:\go\bin;C:\Users\Administrator\go\bin;C:\Program Files` (x86)\GnuWin32\bin"


