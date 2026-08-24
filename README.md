# vigor-gateway-releases
Public installers, documentation, and release assets for VigorLabs Edge Gateway.

## Current Release
You can find and download all release bundles directly from the [GitHub Releases](https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases) page. Each release contains the compiled production binary, installer scripts, local web console, and verified SHA256 checksums.

## Release Bundle Layout
Each Linux bundle is expected to contain:

```text
vigor-gateway-vX.Y.Z-linux-x86_64/
├── bin/gateway
├── config.json.template
├── install.sh
├── install.ps1
├── uninstall.sh
├── uninstall.ps1
├── web/static/index.html
├── vigor-gateway.service
└── SHA256SUMS
```

`install.sh`, `install.ps1`, `uninstall.sh`, and `uninstall.ps1` in this repository are the authoritative installer/uninstaller sources.

## Release Process
The build and publication workflow is maintained in the main project repository.
Use:

`docs/edge-gateway/RELEASE_PROCESS.md`

## Deployment Quickstart
On the target Linux machine:

```bash
# Set your target version (e.g. VERSION=v1.0.19)
export VERSION=v1.0.19

curl -LO "https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/${VERSION}/vigor-gateway-${VERSION}-linux-x86_64.tar.gz"
curl -LO "https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/${VERSION}/vigor-gateway-${VERSION}-linux-x86_64.tar.gz.sha256"
sha256sum -c "vigor-gateway-${VERSION}-linux-x86_64.tar.gz.sha256"
tar -xzf "vigor-gateway-${VERSION}-linux-x86_64.tar.gz"
cd "vigor-gateway-${VERSION}-linux-x86_64"
sudo ./install.sh
```

## Uninstallation
To uninstall the gateway daemon and clean up files:

### Linux
Run the uninstaller script as root:
```bash
sudo ./uninstall.sh
```
To purge configuration files (`/etc/vigor`) as well:
```bash
sudo ./uninstall.sh --purge
```

### Windows
Run the uninstaller script from an Administrator PowerShell console:
```powershell
.\uninstall.ps1
```
To purge configuration files (`C:\ProgramData\VigorLabs\Gateway`) as well:
```powershell
.\uninstall.ps1 -Purge
```
