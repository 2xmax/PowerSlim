# --------------------------------------------------------------------
# Installs FitNesse as Windows Service
# Dependencies: Windows Resource Kit (downloads automatically)
# This script has been tested on Windows 7 and 2008R2
# --------------------------------------------------------------------
param(
[string]$ServiceName = "FitNesse",
[int]$FinessePort = "8084",
[switch]$Uninstall)

#Windows Resource Kit properties
$resourceKitInstallerUrl = "http://download.microsoft.com/download/8/e/c/8ec3a7d8-05b4-440a-a71e-ca3ee25fe057/rktools.exe"
$srvany = "$Env:ProgramFiles*\Windows Resource Kits\Tools\srvany.exe"
$instsrv = "$Env:ProgramFiles*\Windows Resource Kits\Tools\instsrv.exe"

#either export java to PATH env variable or use abs path to executable (e.g. "c:\Program Files (x86)\Java\jdk1.7.0_11\bin\java.exe")
$java_exe = "java"

$fitnesseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$fitnesseJar = (gci (Join-Path $fitnesseDir "fitnesse*.jar")).Name

if($fitnesseJar -eq $null){
    throw "Fitnesse not found. Let you try to put this script behind one. Download page: http://fitnesse.org/FitNesseDownload"
    return
}

function Install-RkTools(){
    Write-Host "Downloading Windows Resource Kit installer"
    $destination = Join-Path $env:temp "rktools.exe"
    $webclient = New-Object System.Net.WebClient
    $webclient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $webclient.DownloadFile($resourceKitInstallerUrl, $destination)
    "Downloaded at $destination"
    #uncpack
    Start-Process $destination "/T:$env:TMP /C" -Wait
    #install
    $msi = Join-Path $env:TMP "rktools.msi"
    Start-Process msiexec "/qn /i $msi" -Wait
    if (-not (Test-Path $srvany)){
        throw "Windows Resource Kit wasn't installed for unknown reason. Let you try to download and install it manually"
    }
}

if (!(Test-Path $srvany)){
    Install-RkTools
}

if(Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"){
    Write-Host "Uninstalling already installed service"
    iex "net stop $ServiceName"
    & $instsrv $ServiceName remove
}

if($Uninstall.IsPresent){
    return
}

Write-Host "Installing service"

$srvany = (gci $srvany).FullName

& $instsrv $ServiceName "`"$srvany`""

$regParamsPath = "HKLM:\System\CurrentControlSet\Services\$ServiceName\Parameters" 
New-Item -Path $regParamsPath
New-ItemProperty -Path $regParamsPath -Name AppDirectory -PropertyType String -Value $fitnesseDir
New-ItemProperty -Path $regParamsPath -Name Application -PropertyType String -Value $java_exe
New-ItemProperty -Path $regParamsPath -Name AppParameters -PropertyType String -Value "-jar $fitnesseJar -p $FinessePort"

iex "net start $ServiceName"

Write-Host "Fitnesse should be available at http://localhost:$FinessePort"
