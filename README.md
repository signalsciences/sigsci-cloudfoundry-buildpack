# sigsci-cloudfoundry-buildpack
Cloud Foundry multi-buildpack for Signal Sciences agent integration

This is a [supply-buildpack](https://docs.cloudfoundry.org/buildpacks/understand-buildpacks.html#supply-script)
for Cloud Foundry that provides integration with the Signal Sciences agent *for any programming
language* supported by the platform, and requiring *zero application code changes*.


### Using the Signal Sciences buildpack

Application developers will need to specify the buildpack with the `cf push` command. From [the docs](https://docs.cloudfoundry.org/buildpacks/use-multiple-buildpacks.html):

`cf push YOUR-APP -b https://github.com/signalsciences/sigsci-cloudfoundry-buildpack.git -b APP_BUILDPACK`

### Windows support
Support is available for Windows stemcells. Deploying to a windows environment is similar to linux:

`cf push YOUR-APP -s windows -b https://github.com/signalsciences/sigsci-cloudfoundry-buildpack.git -b APP_BUILDPACK`

In almost all cases, it will be used in conjunction with the following  buildpacks:
* `binary-buildpack:` [binary-buildpack](https://github.com/cloudfoundry/binary-buildpack) - for console apps, .net core, .exe
* `hwc-buildpack:` [hwc-buildpack](https://github.com/cloudfoundry/hwc-buildpack) - legacy ASP.NET / WCF

### Configuration

To configure the Signal Sciences agent the following environment variables must be set:

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

Every time this buildpack runs it will download and install the latest version of the Signal Sciences agent, unless a version is specified in the app's `SIGSCI_AGENT_VERSION` environment var.

### Releasing the Buildpack

Follow these steps to release a new version of the buildpack:

1. Merge your changes to master.
2. Create a new release on the [releases](https://github.com/signalsciences/sigsci-cloudfoundry-buildpack/releases/new) page.
3. Upon creation of the release, a [workflow](https://github.com/signalsciences/sigsci-cloudfoundry-buildpack/actions) should execute.
4. The workflow will create a tar.gz archive of the bin/ and lib/ directories, and upload it to the release created in step #2.
