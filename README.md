# sigsci-cloudfoundry-buildpack
Cloud Foundry multi-buildpack and buildpack decorator for Signal Sciences agent integration

This is a [supply-buildpack](https://docs.cloudfoundry.org/buildpacks/understand-buildpacks.html#supply-script)
for Cloud Foundry that provides integration with the Signal Sciences agent *for any programming
language* supported by the platform, and requiring *zero application code changes*.

### Installing Signal Sciences buildpack

To install the Signal Sciences buildpack on the target CloudFoundry instance from this repository:
`./upload`

### Using the Signal Sciences buildpack

Application developers will need to specify the buildpack with the `cf push` command. From [the docs](https://docs.cloudfoundry.org/buildpacks/use-multiple-buildpacks.html):

`cf push YOUR-APP -b sigsci-cloudfoundry-buildpack -b APP_BUILDPACK`

### Configuration

To configure the Signal Sciences agent the following enviornment variables must be set:

`SIGSCI_ACCESSKEYID` (required)

`SIGSCI_SECRETACCESSKEY` (required)

`SIGSCI_REVERSE_PROXY_UPSTREAM` (optional, default: 127.0.0.1:8081)

`SIGSCI_AGENT_VERSION` (optional, default: latest)

`SIGSCI_SERVER_HOSTNAME` (optional)

Set environment variables using the `cf` command:

`cf set-env YOUR-APP <variable name> "<value>"`

In order to have these changes take effect, you must at least re-stage your app:

`cf restage YOUR-APP`

### Signal Sciences Agent

Every time this buildpack runs it will download and install the latest version of the Signal Sciences agent, unless a version specified in the app's environment.
