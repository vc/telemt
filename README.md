# Telemt Installation

Automated installation and update scripts for [Telemt](https://github.com/telemt/telemt).

## Quick Install

```bash
curl -sL https://raw.githubusercontent.com/vc/telemt/main/telemt-install.sh | bash
```

The script will:
- Install required dependencies (`curl`, `jq`, `openssl`, `tar`)
- Download the latest telemt binary to `/usr/local/bin`
- Create a default configuration at `/etc/telemt.toml`
- Create a dedicated `telemt` user and group
- Set up and start the systemd service

After installation, user credentials will be displayed in the terminal.

## Update

```bash
curl -sL https://raw.githubusercontent.com/vc/telemt/main/telemt-update.sh | bash
```

The update script will:
- Download the latest release from GitHub
- Compare current and new versions (no update if already latest)
- Stop the service, replace the binary, and restart
- Validate that telemt is running correctly

## Manual Installation of Update Script

To download and make the update script executable:

```bash
curl -sL https://raw.githubusercontent.com/vc/telemt/main/telemt-update.sh -o /opt/telemt-update.sh
chmod +x /opt/telemt-update.sh
```

Run updates manually:

```bash
/opt/telemt-update.sh
```

## Requirements

- Linux (Debian/Ubuntu or similar)
- systemd
- Root privileges (script checks automatically)
- Internet connection to download from GitHub

## Recommendations

**Backup before update**: Although the update script stops the service safely, back up your `/etc/telemt.toml` before major updates if you have custom changes.

**Automated updates via cron**: Add to crontab for automatic daily checks:

```bash
0 3 * * * /opt/telemt-update.sh
```

**Firewall**: Ensure port 443 (or your configured port) is open:

```bash
ufw allow 443/tcp
```

## Configuration

Edit `/etc/telemt.toml` to customize settings. After changes, restart the service:

```bash
systemctl restart telemt
```

## Service Management

```bash
systemctl status telemt    # Check status
systemctl stop telemt      # Stop service
systemctl start telemt     # Start service
systemctl restart telemt   # Restart service
journalctl -u telemt -f    # View logs
```

## Uninstall

```bash
systemctl stop telemt
systemctl disable telemt
rm /usr/local/bin/telemt
rm /etc/telemt.toml
rm /etc/systemd/system/telemt.service
userdel telemt
rm -rf /opt/telemt
```
