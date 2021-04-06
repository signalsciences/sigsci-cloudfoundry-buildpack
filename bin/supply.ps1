Write-Output "-----> SUPPLY Installing signalsciences cloudfoundry scripts"

$buildDir = $args[0]
$depsDir = $args[2]
$index = $args[3]

# create the .profile.d dir
$profileDir = Join-Path $buildDir -ChildPath '.profile.d'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$rootPath = $PSScriptRoot | Split-Path
$sigsciPs1Script = (Join-Path $rootPath -ChildPath 'lib' | Join-Path -ChildPath 'sigsci-agent.ps1')
$sigsciPs1AgentInstallSCript = (Join-Path $depsDir -ChildPath $index | Join-Path -ChildPath 'sigsci-agent.ps1')
$sigsciBatAgentInstallSCript = (Join-Path $profileDir -ChildPath 'sigsci-agent.bat')
$sigsciPs1Exe = "%~dp0\..\..\deps\$index\sigsci-agent.ps1"

# create batch file which will execute the powershell script in the dep/$idx dir
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
echo '@echo off' | Out-File -Encoding ASCII "$sigsciBatAgentInstallSCript"
echo "powershell.exe -ExecutionPolicy Unrestricted -File ""$sigsciPs1Exe""" | Out-File -Append -Encoding ASCII "$sigsciBatAgentInstallSCript"

# copy the sigsci-agent.ps1 script to .profile.d dir
Copy-Item $sigsciPs1Script -Destination $sigsciPs1AgentInstallSCript
