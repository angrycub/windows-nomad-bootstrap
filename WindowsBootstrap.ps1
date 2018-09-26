${CONSUL_ADDR_LIST} = "[]"
${CONSUL_SERVICE_USER_NAME} = "${env:serviceUser}"
${CONSUL_SERVICE_USER_PASS} = "${env:servicePass}"
${NOMAD_SERVICE_USER_NAME} = ${CONSUL_SERVICE_USER_NAME}
${NOMAD_SERVICE_USER_PASS} = ${CONSUL_SERVICE_USER_PASS}
${VAULT_SERVICE_USER_NAME} = ${CONSUL_SERVICE_USER_NAME}
${VAULT_SERVICE_USER_PASS} = ${CONSUL_SERVICE_USER_PASS}

${NOMAD_VERSION} = "0.8.5"
${CONSUL_VERSION} = "1.2.3"
${VAULT_VERSION} = "0.11.1"

${CHOCO_OPTIONS} = "-y --no-progress"

$global:IP = $null     #  This gets set once the function exists. Just here for documentation sake.

function isWindowsServer {
  return ((Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions -Name ProductType) -eq "ServerNT")
}

function Unzip(${zipFile}) {
  If ($PSVersionTable.PSVersion.Major -gt 4) {
    Expand-Archive -path ${zipFile}
  } else {
    DownloadUnzip
    ## Expand-Archive creates a folder of the same name as the archive file
    ## and unzips the archive there.  This preserves that behavior
    $extractPath = [io.path]::GetFileNameWithoutExtension(${zipFile})
    md $extractPath
    unzip.exe -qq ${zipFile} -d $extractPath
  }  
}

function DownloadUnzip {
  MaybeDownloadFile unzip.exe http://www.willus.com/archive/zip64/unzip.exe C:\Windows\System32\unzip.exe
}

function MaybeDownloadFile (${exeName}, ${url}, ${expectedDestination}) {
  if (!(Test-Path ${expectedDestination})) {
    DownloadFile ${exeName} ${url} ${expectedDestination}
  }  
}

function DownloadFile ($exeName, $url, $expectedDestination) {
    Write-Host "Installing $exeName..." -ForegroundColor Green
    wget.exe -q --no-check-certificate ${url}
    Copy ${exeName} ${expectedDestination}
    erase ${exeName}
}

function CreateProductDirectory ($path) {
  mkdir ${path} -ErrorAction SilentlyContinue;
  mkdir ${path}\bin -ErrorAction SilentlyContinue;
  mkdir ${path}\data -ErrorAction SilentlyContinue;
  mkdir ${path}\logs -ErrorAction SilentlyContinue;
  mkdir ${path}\config -ErrorAction SilentlyContinue;
}

function MaybeRemoveSymlink (${fileName}) {
  if (Test-Path ${fileName}) {
    Remove-Item -path ${fileName}
  }  
}

function InstallHashicorpProduct (${product}, ${version}, ${installPath}) {
  CreateProductDirectory ${installPath}
  wget.exe -q --no-check-certificate  https://releases.hashicorp.com/${product}/${version}/${product}_${version}_windows_amd64.zip
  Unzip .\${product}_${version}_windows_amd64.zip
  copy .\${product}_${version}_windows_amd64\${product}.exe ${installPath}\bin\${product}_${version}.exe
  erase .\${product}_${version}_windows_amd64.zip
  erase .\${product}_${version}_windows_amd64 -Recurse
  MaybeRemoveSymlink ${installPath}\bin\${product}.exe
  New-Item -Path ${installPath}\bin\${product}.exe -ItemType SymbolicLink -Value ${installPath}\bin\${product}_${version}.exe
}

function Disable-InternetExplorerESC {
  If (isWindowsServer) {
    ${AdminKey} = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    ${UserKey} = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path ${AdminKey} -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path ${UserKey} -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
  }
}

function Enable-InternetExplorerESC {
  If (isWindowsServer) {
    ${AdminKey} = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    ${UserKey} = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path ${AdminKey} -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path ${UserKey} -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
  }
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

function Set-VirtualTerminalLevel {
  # This allows the Command Prompt window to properly render
  # the ANSI control sequences for the colors and to not leave
  # poop on the screen
  reg add "HKEY_CURRENT_USER\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
}

function Get-DefaultIPAddress {
  ${defaultIface}=Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -ExpandProperty "ifIndex"
  Get-NetIPAddress -InterfaceIndex ${defaultIface} -AddressFamily IPV4 | Select-Object -ExpandProperty "IPAddress"
}

${global:IP}= Get-DefaultIPAddress

function Install-wget {
  Write-Host "Installing wget..." -ForegroundColor Green
  if (!(Test-Path "c:\windows\system32\wget.exe")) {
    ${client} = New-Object System.Net.WebClient;
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
    ${client}.DownloadFile("https://eternallybored.org/misc/wget/1.19.4/64/wget.exe","c:\windows\system32\wget.exe")
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
    `"watches`": [ ]
    `"bootstrap_expect`": 1
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

function CreateHashicorpService (${product},${installPath}, ${serviceUser}, ${servicePass}, ${serviceStartup}) {
  ${productTitle}=${product}
  nssm install ${productTitle} ${installPath}\bin\${product}.exe agent --config-dir="${installPath}\config"
  nssm set ${productTitle} AppDirectory ${installPath}
  nssm set ${productTitle} Description Hashicorp ${productTitle}
  nssm set ${productTitle} Start ${serviceStartup}
  nssm set ${productTitle} ObjectName ${serviceUser} ${servicePass}
  nssm set ${productTitle} AppStdout ${installPath}\logs\${product}.log
  nssm set ${productTitle} AppStderr ${installPath}\logs\${product}.log
  nssm set ${productTitle} AppRotateFiles 1
}

function Install-consul {
  Write-Host "Installing Consul..." -ForegroundColor Green
  InstallHashicorpProduct "consul" "${CONSUL_VERSION}" "C:\Consul"
  Write-Host "   Creating Consul Service..." -ForegroundColor Green
  CreateHashicorpService  "consul" "C:\Consul" ${CONSUL_SERVICE_USER_NAME} ${CONSUL_SERVICE_USER_PASS} "SERVICE_AUTO_START"
  Write-Host "   Creating Consul Lab Service..." -ForegroundColor Green
  CreateProductDirectory("C:\Consul\lab")
  nssm install Consul-Lab C:\Consul\bin\consul.exe agent --config="C:\\Consul\\lab\\config"
  nssm set Consul-Lab AppDirectory C:\Consul\Lab
  nssm set Consul-Lab Description Hashicorp Consul - Lab Agent
  nssm set Consul-Lab Start SERVICE_DEMAND_START
  nssm set Consul-Lab ObjectName ${CONSUL_SERVICE_USER_NAME} ${CONSUL_SERVICE_USER_PASS}
  nssm set Consul-Lab AppStdout C:\Consul\lab\logs\consul.log
  nssm set Consul-Lab AppStderr C:\Consul\lab\logs\consul.log
  nssm set Consul-Lab AppRotateFiles 1
  Write-Host "   Adding Consul to Path..." -ForegroundColor Green
  ${path} = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", ${path} + "C:\Consul\bin;", "User")
}

function Generate-NomadConfig {
@"
  datacenter = `"dc1`"
  data_dir = `"C:\\Nomad\\data`"
  bind_addr = `"${global:IP}`"
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
  bind_addr = `"${global:IP}`"
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
  InstallHashicorpProduct "nomad" "${NOMAD_VERSION}" "C:\Nomad"
  Write-Host "   Creating Nomad Service..." -ForegroundColor Green
  CreateHashicorpService  "nomad" "C:\Nomad" ${NOMAD_SERVICE_USER_NAME} ${NOMAD_SERVICE_USER_PASS} "SERVICE_AUTO_START"
  Write-Host "   Creating Nomad Lab Service..." -ForegroundColor Green
  CreateProductDirectory "C:\Nomad\lab"
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
  InstallHashicorpProduct "vault" "${VAULT_VERSION}" "C:\Vault"
  Write-Host "   Creating Vault Service..." -ForegroundColor Green
  CreateHashicorpService  "vault" "C:\Vault" ${VAULT_SERVICE_USER_NAME} ${VAULT_SERVICE_USER_PASS} "SERVICE_AUTO_START"
  Write-Host "   Adding Vault to Path..." -ForegroundColor Green
  $path = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", $path + "C:\Vault\bin;", "User")
}

function Install-chocolatey {
  Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

function Install-vim { choco install ${CHOCO_OPTIONS} vim }

function Install-git { choco install ${CHOCO_OPTIONS} git }

function Install-golang { choco install ${CHOCO_OPTIONS} golang }

function Install-coreutils { choco install ${CHOCO_OPTIONS} gnuwin32-coreutils.install }

function Install-googlechrome { choco install ${CHOCO_OPTIONS} googlechrome }

function Install-sublime { choco install ${CHOCO_OPTIONS} sublimetext3 sublimetext3.powershellalias }

function Install-docker {
  Write-Host "Installing Docker (this will reboot the node)..." -ForegroundColor Green
  choco install ${CHOCO_OPTIONS} docker-for-windows
  Install-WindowsFeature -Name Hyper-V  -IncludeManagementTools 
  Install-WindowsFeature -Name Containers -IncludeManagementTools
  Write-Host "Rebooting the node..." -ForegroundColor Yellow
  Restart-Computer -Force
}

function Install-devTools {
  Install-git
  Install-coreutils
  Install-golang 
}

clear

Disable-InternetExplorerESC
Enable-RemoteDesktop 
Set-VirtualTerminalLevel
Install-wget
Install-nssm
Install-consul
Generate-ConsulConfig
Install-nomad
Generate-NomadConfig
Generate-NomadLabConfig
Install-vault
Generate-VaultConfig
Install-chocolatey
Install-devTools
Install-docker
