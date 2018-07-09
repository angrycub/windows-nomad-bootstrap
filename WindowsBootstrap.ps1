
$CONSUL_ADDR_LIST = 
$CONSUL_SERVICE_USER_NAME = ".\Administrator"
$CONSUL_SERVICE_USER_PASS = "«YOUR_ADMIN_PASSWORD»"
$NOMAD_SERVICE_USER_NAME = $CONSUL_SERVICE_USER_NAME
$NOMAD_SERVICE_USER_PASS = $CONSUL_SERVICE_USER_PASS
$NOMAD_VERSION= "0.8.4"
$CONSUL_VERSION = "1.0.2"

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
  $client = New-Object System.Net.WebClient;
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
  $client.DownloadFile("https://eternallybored.org/misc/wget/1.19.4/64/wget.exe","c:\windows\system32\wget.exe")
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
    "retry_join": ["10.0.0.215","10.0.0.108","10.0.0.220"],
    "bind_addr": "$global:IP",
    "client_addr": "0.0.0.0",
    "datacenter": "dc1",
    "data_dir": "C:\\Consul\\data",
    "log_level": "DEBUG",
    "node_name": "$env:computername",
    "watches": [ ]
  }
"@ | Out-File -Encoding ASCII -FilePath C:\Consul\config\consul.json
}

function Install-consul {
  Write-Host "Installing Consul..." -ForegroundColor Green
  mkdir C:\Consul\bin -ErrorAction SilentlyContinue;
  mkdir c:\Consul\data -ErrorAction SilentlyContinue;
  mkdir c:\Consul\logs -ErrorAction SilentlyContinue;
  mkdir c:\Consul\config -ErrorAction SilentlyContinue;
  wget.exe -q --no-check-certificate  https://releases.hashicorp.com/consul/1.0.2/consul_1.0.2_windows_amd64.zip
  Unzip .\consul_1.0.2_windows_amd64.zip
  copy .\consul_1.0.2_windows_amd64\consul.exe C:\Consul\bin
  erase .\consul_1.0.2_windows_amd64.zip
  erase .\consul_1.0.2_windows_amd64 -Recurse
  Write-Host "   Creating Consul Service..." -ForegroundColor Green
  nssm install Consul C:\Consul\bin\consul.exe agent --config-dir="C:\\Consul\\config"
  nssm set Consul AppDirectory C:\Consul
  nssm set Consul Description Hashicorp Consul
  nssm set Consul Start SERVICE_AUTO_START
  nssm set Consul ObjectName $CONSUL_SERVICE_USER_NAME $CONSUL_SERVICE_USER_PASS
  nssm set Consul AppStdout C:\Consul\logs\consul.log
  nssm set Consul AppStderr C:\Consul\logs\consul.log
  nssm set Consul AppRotateFiles 1
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
"@ | Out-File -Encoding ASCII -FilePath C:\Nomad\config\nomad.hcl
}

function Install-nomad {
  Write-Host "Installing Nomad..." -ForegroundColor Green
  mkdir c:\Nomad\bin -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\data -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\logs -ErrorAction SilentlyContinue;
  mkdir c:\Nomad\config -ErrorAction SilentlyContinue;
  wget.exe -q --no-check-certificate https://releases.hashicorp.com/nomad/0.8.3/nomad_0.8.3_windows_amd64.zip
  Unzip .\nomad_0.8.3_windows_amd64.zip
  copy .\nomad_0.8.3_windows_amd64\nomad.exe C:\Nomad\bin\nomad_0.8.3.exe
  erase .\nomad_0.8.3_windows_amd64.zip
  erase .\nomad_0.8.3_windows_amd64 -Recurse
  New-Item -Path C:\Nomad\bin\nomad.exe -ItemType SymbolicLink -Value C:\Nomad\bin\nomad_0.8.3.exe
  Write-Host "   Creating Nomad Service..." -ForegroundColor Green
  nssm install Nomad C:\Nomad\bin\nomad.exe agent --config="C:\\Nomad\\config"
  nssm set Nomad AppDirectory C:\Nomad
  nssm set Nomad Description Hashicorp Nomad
  nssm set Nomad DependOnService Consul
  nssm set Nomad Start SERVICE_AUTO_START
  nssm set Nomad ObjectName $NOMAD_SERVICE_USER_NAME $NOMAD_SERVICE_USER_PASS
  nssm set Nomad AppStdout C:\Nomad\logs\nomad.log
  nssm set Nomad AppStderr C:\Nomad\logs\nomad.log
  nssm set Nomad AppRotateFiles 1
  Write-Host "   Adding Nomad to Path..." -ForegroundColor Green
  $path = [System.Environment]::GetEnvironmentVariable("Path", "User")
  [System.Environment]::SetEnvironmentVariable("Path", $path + "C:\Nomad\bin;", "User")
  [System.Environment]::SetEnvironmentVariable("NOMAD_ADDR", "http://${global:IP}:4646", "User")
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

clear

Disable-InternetExplorerESC
Enable-RemoteDesktop 
Install-wget
Install-nssm
Install-consul
Generate-ConsulConfig
Install-nomad
Generate-NomadConfig

### I have Install-docker commented out because I need to
### change this to download Docker CE and install the MSI.
### The current implementation will work, it just loads the
### Windows container implementation

#Install-docker




### $env:PATH="${env:PATH}C:\go\bin;C:\Users\Administrator\go\bin;C:\Program Files` (x86)\GnuWin32\bin"


