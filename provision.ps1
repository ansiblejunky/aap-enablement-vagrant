# This uses Vagrant's existing WinRM connection; it cannot bootstrap it.
$ErrorActionPreference = 'Stop'

Write-Host "Guest: $env:COMPUTERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Get-CimInstance -ClassName Win32_OperatingSystem |
    Select-Object Caption, Version, OSArchitecture
Get-Service -Name WinRM | Select-Object Name, Status, StartType
Get-ChildItem WSMan:\localhost\Listener
