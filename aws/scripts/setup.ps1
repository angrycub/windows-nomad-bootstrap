 function Install-docker {
  Write-Host "Installing Docker (this will reboot the node)..." -ForegroundColor Green
  Install-Module -Name DockerMsftProvider -Force
  Install-Package -Name docker -ProviderName DockerMsftProvider -Force
  Write-Host "Rebooting the node..." -ForegroundColor Yellow
  Restart-Computer -Force
}
function isWindowsServer {
  return ((Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions -Name ProductType) -eq "ServerNT")
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

Disable-InternetExplorerESC
Enable-RemoteDesktop
Disable-UserAccessControl
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install sublimetext3 -y
choco install googlechrome -y
Install-docker