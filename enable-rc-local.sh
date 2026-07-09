#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define file paths
RC_LOCAL="/etc/rc.local"
SERVICE_FILE="/etc/systemd/system/rc-local.service"

echo "=== Starting rc.local Compatibility Setup ==="

# 0. Sanity checks: must be root, must be a systemd system
if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (e.g. via sudo)." >&2
    exit 1
fi

if ! command -v systemctl > /dev/null; then
    echo "Error: this system does not appear to use systemd." >&2
    echo "Classic rc.local support may already work natively here." >&2
    exit 1
fi

# 1. Create the /etc/rc.local file if it doesn't exist
if [ ! -f "$RC_LOCAL" ]; then
    echo "Creating $RC_LOCAL..."
    tee "$RC_LOCAL" > /dev/null << 'EOF'
#!/bin/bash
#
# rc.local - Custom startup commands go here
# Note: systemd invokes this script with a "start" argument
# (traditional sysvinit convention); it can safely be ignored.
# Ensure this script exits with 0 on success

exit 0
EOF
else
    echo "$RC_LOCAL already exists. Skipping creation."
fi

# 2. Make it executable
echo "Setting executable permissions on $RC_LOCAL..."
chmod +x "$RC_LOCAL"

# 2b. Fix the SELinux label so systemd is allowed to execute it
# (a file created in /etc gets a generic etc_t label; enforcing
# SELinux systems like Fedora/RHEL need initrc_exec_t)
if command -v restorecon > /dev/null; then
    echo "Restoring SELinux context on $RC_LOCAL..."
    restorecon "$RC_LOCAL"
fi

# 3. Create the systemd service unit file
echo "Creating systemd service file at $SERVICE_FILE..."
tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.local
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF

# 4. Reload systemd, enable, and start the service
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling rc-local.service to run at boot..."
systemctl enable rc-local.service

echo "Starting rc-local.service..."
if ! systemctl start rc-local.service; then
    echo "Warning: rc-local.service failed to start." >&2
    echo "The setup itself succeeded; check the commands in $RC_LOCAL." >&2
    echo "See: journalctl -u rc-local.service" >&2
fi

# 5. Verify the results
echo "=== Setup complete! Verifying status: ==="
systemctl status rc-local.service --no-pager || true
