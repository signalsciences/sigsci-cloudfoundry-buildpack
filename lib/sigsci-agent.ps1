echo "Setting up sigsci agent"

Function health_check([string[]]$hc_config, [string]$listener_port, [string]$upstream_port, [int]$initial_sleep)
{
    $hc_frequency = $hc_config[0]
    $hc_endpoint = $hc_config[1]
    $hc_listener_kill_on_status = $hc_config[2]
    $hc_listener_warning = $hc_config[3]
    $hc_upstream_kill_not_status = $hc_config[4]
    $hc_upstream_warning = $hc_config[5]
    $hc_listener_port = $listener_port
    $hc_upstream_port = $upstream_port

    $listener_warning_count = 0
    $upstream_warning_count = 0

    # health check logic
    $hc = {
        while ($true)
        {
            Start-Sleep -s $hc_frequency
            # check the listener process
            $listener_status = (Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$hc_listener_port$hc_endpoint" -TimeoutSec 3).StatusCode

            # check the upstream process
            $upstream_status = (Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$hc_upstream_port$hc_endpoint" -TimeoutSec 3).StatusCode

            if (($listener_status -eq $hc_listener_kill_on_status) -or (000 -eq $listener_status))
            {
                $listener_warning_count++

                if ($listener_warning_count -gt $hc_listener_warning)
                {
                    Write-Output "Listener became unhealthy! Killing sigsci-agent.exe process"
                    Stop-Process -Name "sigsci-agent"
                    return
                }
                else
                {
                    Write-Output "WARNING: sigsci-agent HC_LISTENER_WARNING at $listener_warning_count out of $hc_listener_warning."
                }
            }
            else
            {
                $listener_warning_count = 0
            }

            # verify upstream status
            if (($upstream_status -ne $hc_upstream_kill_not_status) -or ( 000 -eq $upstream_status))
            {
                $upstream_warning_count++

                if ($upstream_warning_count -gt $hc_upstream_warning)
                {
                    Write-Output "Upstream became unhealthy! Killing sigsci-agent.exe process"
                    Stop-Process -Name "sigsci-agent"
                    return
                }
                else
                {
                    Write-Output "WARNING: sigsci-agent HC_UPSTREAM_WARNING at $upstream_warning_count out of $hc_upstream_warning."
                }
            }
            else
            {
                $upstream_warning_count = 0
            }
        }
    }

    Start-Sleep -s $initial_sleep


    Start-Job -Name "SigSci-HealthCheck" -ScriptBlock $hc
}

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
        $sigsci_agent_version = (Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.signalsciences.net/sigsci-agent/VERSION').Content.TrimEnd("`r?`n")

    }

    # check if $sigsci_agent_version exists
    $status = (Invoke-WebRequest -UseBasicParsing -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/VERSION").StatusCode

    if (-not ($status -eq 200))
    {
        # skip agent install if $status not 200
        Write-Output "-----> SigSci Agent version $sigsci_agent_version not found or network unavailable after 90 seconds!"
        Write-Output "-----> SIGSCI AGENT WILL NOT BE INSTALLED!"
    } else {
        Write-Output "-----> Downloading sigsci-agent"
        Invoke-WebRequest -UseBasicParsing -OutFile "sigsci-agent_$sigsci_agent_version.zip" `
                -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/windows/sigsci-agent_$sigsci_agent_version.zip"

        if (-not(Test-Path env:SIGSCI_DISABLE_CHECKSUM_INTEGRITY_CHECK))
        {
            # download the .sha256 file
            Invoke-WebRequest -UseBasicParsing `
                -OutFile "sigsci-agent_$sigsci_agent_version.zip.sha256" `
                -Uri "https://dl.signalsciences.net/sigsci-agent/$sigsci_agent_version/windows/sigsci-agent_$sigsci_agent_version.zip.sha256"

            # compute hash and verify against .sha256
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
        $port_listener = $Env:PORT
        $port_upstream = 8081
        $sigsci_upstream = "127.0.0.1:$port_upstream"
        $sigsci_config_file = "$sigsci_dir\conf\agent.conf"

        # optional config environment variables, if not provided default value will be used.

        # reverse proxy upstream
        if (-not(Test-Path env:SIGSCI_REVERSE_PROXY_UPSTREAM))
        {
            Write-Output "-----> SIGSCI_REVERSE_PROXY_UPSTREAM not provided, using default: $sigsci_upstream"
        }
        else
        {
            $sigsci_upstream = $Env:SIGSCI_REVERSE_PROXY_UPSTREAM
            $port_upstream = $sigsci_upstream.split(':')[1]
        }

        # reverse proxy accesslog - disable access logging by default.
        if (-not(Test-Path env:SIGSCI_REVERSE_PROXY_ACCESSLOG))
        {
            $sigsci_reverse_proxy_accesslog = ''
        }
        else
        {
            $sigsci_reverse_proxy_accesslog = $Env:SIGSCI_REVERSE_PROXY_ACCESSLOG
        }

        # require signal sciences agent for app to start.
        # this prevent port reassignment in the event the agent fails to start.
        # as a result, cloud foundry will detect the app as unhealthy.
        # default is to not require the agent.
        if (-not(Test-Path env:SIGSCI_REQUIRED))
        {
            $sigsci_required = "false"
        }
        else
        {
            $sigsci_required = $Env:SIGSCI_REQUIRED
        }

        # health check - disable by default.
        if (-not(Test-Path env:SIGSCI_HC))
        {
            $sigsci_hc = "false"
        }
        else
        {
            $sigsci_hc = $Env:SIGSCI_HC
        }

        # health check - initial sleep.
        if (-not(Test-Path env:SIGSCI_HC_INIT_SLEEP))
        {
            $sigsci_hc_init_sleep = 30
        }
        else
        {
            $sigsci_hc_init_sleep = $Env:SIGSCI_HC_INIT_SLEEP
        }

        # health check config
        #
        # HC_CONFIG fields:
        # <frequency>:<endpoint>:<listener status>:<listener warning>:<upstream status>:<upstream warning>
        #
        # frequency - how often to perform the check in seconds, e.g. every 5 seconds.
        # endpoint - which endpoint to check for both the listener and upstream process.
        # listener status - the status code that not healthy and will trigger killing the agent.
        # listener warning - the number of times the check can fail before killing the agent.
        # upstream status = the status code that is healthy, any other code will trigger killing the agent.
        # upstream warning - the number of times the check can fail before killing the agent.
        #
        # Note: the listener port is defined by the PORT_LISTENER variable.
        # Note: the upstream port is defined by the PORT_UPSTREAM variable.
        # Note: the PID to kill is defined by the SIGSCI_PID variable.
        if (-not(Test-Path env:SIGSCI_HC_CONFIG))
        {
            $sigsci_hc_config = @('5','/','502','5','200','3')
        }
        else
        {
            $sigsci_hc_config = "$Env:SIGSCI_HC_CONFIG".split(":")
        }

        # reassign PORT for application process.
        $Env:PORT = $port_upstream

        $sigsci_config = @"
server-flavor="sigsci-module-cloudfoundry"
# Signal Sciences Reverse Proxy Config
[revproxy-listener.http2]
listener="http://0.0.0.0:$($port_listener)"
upstreams="http://$($sigsci_upstream)"
access-log="$($sigsci_reverse_proxy_accesslog)"
"@

        $sigsci_config -f 'string' | Out-File $sigsci_config_file -Encoding ascii

        # start the agent
        Write-Output "-----> Starting Signal Sciences Agent!"

        # Remove any deprecated reverse proxy config options
        if (Test-Path env:SIGSCI_REVERSE_PROXY_*)
        {
            Copy-Item -Path $Env:SIGSCI_REVERSE_PROXY_* -Destination $Env:SIGSCI_REVPROXY
        }

        Write-Output "!!!I'm currently in $pwd"
        Write-Output "!!!sigsci_dir is $sigsci_dir"
        Write-Output "!!!sigsci_config_file is $sigsci_config_file"
        Start-Process $sigsci_dir\bin\sigsci-agent.exe --config="$sigsci_config_file" `
            -WorkingDirectory "$sigsci_dir\bin" -WindowStyle Hidden -PassThru

        # wait for agent to start
        Start-Sleep -s 5

        # Check if agent is running. If not, reassign port so app can start.
        if (-not(Get-Process sigsci-agent))
        {
            if ($Env:SIGSCI_REQUIRED -eq "true")
            {
                Write-Output "-----> Signal Sciences failed to start!"
                Write-Output "-----> SIGSCI_REQUIRED is enabled, port reassignment will not occur and app will be unhealthy!!!"
            } else {
                $Env:PORT = $port_listener
                Write-Output "-----> Signal Sciences failed to start!"
                Write-Output "-----> Deploying application without Signal Sciences enabled!!!"
            }
        } else {
            Write-Output "!!!sigsci-agent started"
            if ($sigsci_hc -eq "true")
            {
                Write-Output "-----> sigsci-agent health checks enabled. Health checks will start in $sigsci_hc_init_sleep seconds."

                # call hc func
            }
        }
    }
}
else
{
    Write-Output "-----> Signal Sciences access keys not set. Agent not starting!!!"
    Write-Output "-----> To enable the Signal Sciences agent please set the following environment variables:"
    Write-Output "-----> SIGSCI_ACCESSKEYID"
    Write-Output "-----> SIGSCI_SECRETACCESSKEY"
}