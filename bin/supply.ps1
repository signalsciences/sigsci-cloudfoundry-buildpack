echo "-----> SUPPLY Installing signalsciences cloudfoundry scripts"

$buildDir = $args[0]
$depsDir = $args[2]
$index = $args[3]

# create the .profile.d dir
$profileDir = Join-Path $buildDir -ChildPath '.profile.d'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null

$rootPath = $PSScriptRoot | Split-Path
$sigsciPs1Script = (Join-Path $rootPath -ChildPath 'lib' | Join-Path -ChildPath 'sigsci-agent.ps1')
$sigsciBatScript = (Join-Path $rootPath -ChildPath 'lib' | Join-Path -ChildPath 'sigsci-agent.bat')

# copy the sigsci-agent.ps1 script to .profile.d dir
Copy-Item $sigsciPs1Script -Destination $profileDir
Copy-Item $sigsciBatScript -Destination $profileDir
