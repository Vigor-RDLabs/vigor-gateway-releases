# vigor-gateway-releases
Public installers, documentation, and release assets for VigorLabs Edge Gateway.

## Current Release
- Latest published release as of August 10, 2026: [`v1.0.7`](https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/tag/v1.0.7)
- Linux asset:
  `vigor-gateway-v1.0.7-linux-x86_64.tar.gz`
- Tarball checksum asset:
  `vigor-gateway-v1.0.7-linux-x86_64.tar.gz.sha256`

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
curl -LO https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/v1.0.7/vigor-gateway-v1.0.7-linux-x86_64.tar.gz
curl -LO https://github.com/Vigor-RDLabs/vigor-gateway-releases/releases/download/v1.0.7/vigor-gateway-v1.0.7-linux-x86_64.tar.gz.sha256
sha256sum -c vigor-gateway-v1.0.7-linux-x86_64.tar.gz.sha256
tar -xzf vigor-gateway-v1.0.7-linux-x86_64.tar.gz
cd vigor-gateway-v1.0.7-linux-x86_64
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
