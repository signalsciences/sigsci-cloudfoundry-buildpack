echo "Setting up sigsci agent"

if (-not (Test-Path env:PORT))
{
    Write-Output "-----> Cloud Foundry PORT not set and cannot determine configuration. Agent not starting!!!"
    exit
}

if ((Test-Path env:SIGSCI_ACCESSKEYID) -and (Test-Path env:SIGSCI_SECRETACCESSKEY))
{

}
exit