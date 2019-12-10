#!/usr/bin/env bash

# health check function
function health_check() {
  IFS=':' read -a hc_config <<< "${SIGSCI_HC_CONFIG}"

  HC_FREQUENCY=${hc_config[0]}
  HC_ENDPOINT=${hc_config[1]}
  HC_LISTENER_PORT=${PORT_LISTENER}
  HC_LISTENER_KILL_ON_STATUS=${hc_config[2]}
  HC_LISTENER_WARNING=${hc_config[3]}
  HC_UPSTREAM_PORT=${PORT_UPSTREAM}
  HC_UPSTREAM_KILL_NOT_STATUS=${hc_config[4]}
  HC_UPSTREAM_WARNING=${hc_config[5]}

  listener_warning_count=0
  upstream_warning_count=0

  # let's give the app time to start up.
  sleep $SIGSCI_HC_INIT_SLEEP

  while true;
  do
    sleep $HC_FREQUENCY;

    # check the listener process
    LISTENER_STATUS=$(curl -s -X GET -m 3 -A "sigsci-health-check" -o /dev/null -w "%{http_code}" http://localhost:${HC_LISTENER_PORT}${HC_ENDPOINT})

    # check the upstream process
    UPSTREAM_STATUS=$(curl -s -X GET -m 3 -A "sigsci-health-check" -o /dev/null -w "%{http_code}" http://localhost:${HC_UPSTREAM_PORT}${HC_ENDPOINT})

    # verify listener status
    if [ $LISTENER_STATUS -eq $HC_LISTENER_KILL_ON_STATUS ] || [ 000 -eq $LISTENER_STATUS ];
    then
      ((listener_warning_count++))

      if [ $listener_warning_count -gt $HC_LISTENER_WARNING ];
      then
        >2& echo "Listener became unhealthy! Killing sigsci-agent with PID ${SIGSCI_PID}."
        kill -9 $SIGSCI_PID
        break
      else
        echo "WARNING: sigsci-agent HC_LISTENER_WARNING at ${listener_warning_count} out of ${HC_LISTENER_WARNING}."
      fi
    else
      # reset counter if health is good
      listener_warning_count=0
    fi

    # verify upstream status
    if [ $UPSTREAM_STATUS -ne $HC_UPSTREAM_KILL_NOT_STATUS ] || [ 000 -eq $UPSTREAM_STATUS ];
    then
      ((upstream_warning_count++))

      if [ $upstream_warning_count -gt $HC_UPSTREAM_WARNING ];
      then
        >2& echo "Upstream became unhealthy! Killing sigsci-agent with PID ${SIGSCI_PID}"
        kill -9 $SIGSCI_PID
        break
      else
        echo "WARNING: sigsci-agent HC_UPSTREAM_WARNING at ${upstream_warning_count} out of ${HC_UPSTREAM_WARNING}."
      fi
    else
        # reset counter if health is good
        upstream_warning_count=0
    fi
  done

  exit
}

# Sanity check for CF env
if [ -z "${PORT}" ]; then
  (>&2 echo "-----> Cloud Foundry PORT not set and cannot determine configuration. Agent not starting!!!")
  exit
fi

# check if access keys are defined.
# if defined, then proceed with install. Othewise, skip install.
if [ -n "${SIGSCI_ACCESSKEYID}" -a -n "${SIGSCI_SECRETACCESSKEY}" ]
then
  # setup directories
  PWD=`pwd`
  SIGSCI_DIR=${PWD}/.profile.d/sigsci
  mkdir -p $SIGSCI_DIR/bin
  mkdir -p $SIGSCI_DIR/conf

  ## install agent

  # if agent version not specified then get the latest version.
  if [ -z $SIGSCI_AGENT_VERSION ]
  then
    SIGSCI_AGENT_VERSION=$(curl -s -L --retry 45 --retry-delay 2 https://dl.signalsciences.net/sigsci-agent/VERSION)
  fi

  # check if version exists.
  STATUS=$(curl -s --retry 45 --retry-delay 2 -o /dev/null -w "%{http_code}" https://dl.signalsciences.net/sigsci-agent/${SIGSCI_AGENT_VERSION}/VERSION)
  if [ $STATUS -ne 200 ]
  then

    # if we don't get a 200 response, skip agent installation.
    (>&2 echo "-----> SigSci Agent version ${SIGSCI_AGENT_VERSION} not found or network unavailable after 90 seconds!")
    (>&2 echo "-----> SIGSCI AGENT WILL NOT BE INSTALLED!")

  else
    echo "-----> Downloading sigsci-agent"
    curl -s --retry 45 --retry-delay 2 -o sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz https://dl.signalsciences.net/sigsci-agent/${SIGSCI_AGENT_VERSION}/linux/sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz > /dev/null

    if [ -z $SIGSCI_DISABLE_CHECKSUM_INTEGRITY_CHECK ]
    then
        curl -s --retry 45 --retry-delay 2 -o sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz.sha256 https://dl.signalsciences.net/sigsci-agent/${SIGSCI_AGENT_VERSION}/linux/sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz.sha256 > /dev/null

        # validate the gzip file
        if [[ "$(shasum -c sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz.sha256)" != *"OK"* ]]
        then
            (>&2 echo "-----> sigsci-agent not installed")
            exit 1
        fi
    fi

    tar -xzf "sigsci-agent_${SIGSCI_AGENT_VERSION}.tar.gz"
    mv sigsci-agent "${SIGSCI_DIR}/bin/sigsci-agent"
    echo "-----> Finished installing sigsci-agent"

    # do config
    PORT_LISTENER=${PORT}
    PORT_UPSTREAM=8081
    SIGSCI_UPSTREAM=127.0.0.1:${PORT_UPSTREAM}
    SIGSCI_CONFIG_FILE=${SIGSCI_DIR}/conf/agent.conf

    ## optional config variable, if not provided default value will be used.

    # reverse proxy upstream
    if [ -z ${SIGSCI_REVERSE_PROXY_UPSTREAM} ]
    then
      echo "-----> SIGSCI_REVERSE_PROXY_UPSTREAM not provided, using default: ${SIGSCI_UPSTREAM}"
    else
      SIGSCI_UPSTREAM=${SIGSCI_REVERSE_PROXY_UPSTREAM}
      IFS=':' read -a upstream_parts <<< "${SIGSCI_UPSTREAM}"
      PORT_UPSTREAM=${upstream_parts[1]}
    fi

    # reverse proxy accesslog - disable access logging by default.
    if [ -z $SIGSCI_REVERSE_PROXY_ACCESSLOG ]
    then
      SIGSCI_REVERSE_PROXY_ACCESSLOG=''
    fi

    # require signal sciences agent for app to start.
    # this prevent port reassignment in the event the agent fails to start.
    # as a result, cloud foundry will detect the app as unhealthy.
    # default is to not require the agent.
    if [ -z $SIGSCI_REQUIRED ]
    then
      SIGSCI_REQUIRED="false"
    fi

    # health check - disable by default.
    if [ -z $SIGSCI_HC ]
    then
      SIGSCI_HC="false"
    fi

    # health check - initial sleep.
    if [ -z $SIGSCI_HC_INIT_SLEEP ]
    then
      SIGSCI_HC_INIT_SLEEP=30
    fi

    # reassign PORT for application process.
    export PORT=${PORT_UPSTREAM}

    cat > ${SIGSCI_CONFIG_FILE} <<EOT
# Signal Sciences Reverse Proxy Config
[revproxy-listener.http]
listener = "http://0.0.0.0:${PORT_LISTENER}"
upstreams = "http://${SIGSCI_UPSTREAM}"
access-log = "${SIGSCI_REVERSE_PROXY_ACCESSLOG}"
EOT

    # start agent
    echo "-----> Starting Signal Sciences Agent!"
    (
      # Remove any deprecated reverse proxy config options
      export -n SIGSCI_REVPROXY $(env | grep ^SIGSCI_REVERSE_PROXY_ | awk -F= '{print $1}');
      ${SIGSCI_DIR}/bin/sigsci-agent --config="${SIGSCI_CONFIG_FILE}"
    ) &

    SIGSCI_PID=$!

    # wait plenty of time for agent to startup
    sleep 5

    # check if agent is running
    kill -0 $SIGSCI_PID 2>/dev/null

    # if not running, reassign port so app can start.
    if [ $? -ne 0 ];
    then
      if [ "true" = "$SIGSCI_REQUIRED" ];
      then
        (>&2 echo "-----> Signal Sciences failed to start!")
        (>&2 echo "-----> SIGSCI_REQUIRED is enabled, port reassignment will not occur and app will be unhealthy!!!")
      else
        export PORT=${PORT_LISTENER}
        (>&2 echo "-----> Signal Sciences failed to start!")
        (>&2 echo "-----> Deploying application without Signal Sciences enabled!!!")
      fi
    else
      # if health check is enabled, do health checking.
      if [ "true" = "$SIGSCI_HC" ];
      then
        echo "sigsci-agent health checks enabled. Health checks will start in ${SIGSCI_HC_INIT_SLEEP} seconds."
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
        #
        if [ -z $SIGSCI_HC_CONFIG ];
        then
          # default health check config
          SIGSCI_HC_CONFIG="5:/:502:5:200:3"
        fi

        health_check &
      fi
    fi
  fi

else
  (>&2 echo "-----> Signal Sciences access keys not set. Agent not starting!!!")
  (>&2 echo "-----> To enable the Signal Sciences agent please set the following environment variables:")
  (>&2 echo "-----> SIGSCI_ACCESSKEYID")
  (>&2 echo "-----> SIGSCI_SECRETACCESSKEY")
fi
