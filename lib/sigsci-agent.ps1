echo "Setting up sigsci agent"

# check if the PORT envirornment variable is set
if (-not (Test-Path env:PORT))
{
    Write-Output "-----> Cloud Foundry PORT not set and cannot determine configuration. Agent not starting!!!"
    exit
}

# check if SIGSCI_ACCESSKEYID and SIGSCI_SECRETACCESSKEY are set before proceeding with agent installation
if ((Test-Path env:SIGSCI_ACCESSKEYID) -and (Test-Path env:SIGSCI_SECRETACCESSKEY))
{
    # setup directories
    $sigsci_dir = (Join-Path $pwd -ChildPath '.profile.d' | Join-Path -ChildPath 'sigsci')
    New-Item -ItemType Directory -Force -Path $sigsci_dir\bin | Out-Null
    New-Item -ItemType Directory -Force -Path $sigsci_dir\conf | Out-Null

    # install sigsci agent

    # if agent version not specified then get the latest version.
    if (-not (Test-Path env:SIGSCI_AGENT_VERSION))
    {
        $sigsci_agent_version = (Invoke-WebRequest `
                                    -MaximumRetryCount 45 `
                                    -RetryIntervalSec 2 `
                                    -Uri 'https://dl.signalsciences.net/sigsci-agent/VERSION').Content.TrimEnd("`r?`n")

    }

    # check if $sigsci_agent_version exists
    $status = (Invoke-WebRequest `
        -MaximumRetryCount 45 `
        -RetryIntervalSec 2 `
        -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/VERSION").StatusCode

    if (-not ($status -eq 200))
    {
        # skip agent install if $status not 200
        Write-Output "-----> SigSci Agent version $sigsci_agent_version not found or network unavailable after 90 seconds!"
        Write-Output "-----> SIGSCI AGENT WILL NOT BE INSTALLED!"
    } else {
        Write-Output "-----> Downloading sigsci-agent"
        Invoke-WebRequest -MaximumRetryCount 45 -RetryIntervalSec 2 `
            -OutFile "sigsci-agent_$sigsci_agent_version.zip" `
            -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/windows/sigsci-agent_$sigsci_agent_version.zip"

        if (-not(Test-Path env:SIGSCI_DISABLE_CHECKSUM_INTEGRITY_CHECK))
        {
            # download the .sha256 file
            Invoke-WebRequest -MaximumRetryCount 45 -RetryIntervalSec 2 `
                -OutFile "sigsci-agent_$sigsci_agent_version.zip.sha256" `
                -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/windows/sigsci-agent_$sigsci_agent_version.zip.sha256"

            $computed_hash = (Get-FileHash -Algorithm SHA256 "./sigsci-agent_$sigsci_agent_version.zip").Hash
            $hash = Select-String -Path "./sigsci-agent_$sigsci_agent_version.zip.sha256" -Pattern  $computed_hash -Quiet
            if (-not (Select-String -Path "./sigsci-agent_$sigsci_agent_version.zip.sha256" -Pattern $computed_hash -Quiet))
            {
                Write-Output "-----> sigsci-agent not installed because checksum integrity check failed"
                exit 1
            }
        }

        Expand-Archive -Path "sigsci-agent_$sigsci_agent_version.zip" -DestinationPath $sigsci_dir\bin
        Write-Output "-----> Finished installing sigsci-agent"

        # configure the agent

    }
}
else
{
    Write-Output "-----> Signal Sciences access keys not set. Agent not starting!!!"
    Write-Output "-----> To enable the Signal Sciences agent please set the following environment variables:"
    Write-Output "-----> SIGSCI_ACCESSKEYID"
    Write-Output "-----> SIGSCI_SECRETACCESSKEY"
}