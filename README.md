# enable-rc.local

Bring back simple `/etc/rc.local` startup scripts on modern systemd distributions.

## What it does

Classic Unix systems let you drop startup commands into a single file — `/etc/rc.local` — and they ran at boot. No unit files, no dependency graphs, no boilerplate. Modern distributions have deprecated or removed this mechanism in favor of systemd, which means even trivial "run this one command at boot" tasks require writing a systemd service.

`enable-rc-local.sh` restores the old behavior with one command. It:

1. Creates `/etc/rc.local` (with a safe template) if it doesn't already exist
2. Makes it executable
3. Fixes the SELinux label (`restorecon`) so systemd is allowed to execute it on enforcing systems like Fedora and RHEL
4. Installs a small `rc-local.service` systemd unit that runs `/etc/rc.local` at boot, after the network is online
5. Enables and starts the service, then shows its status

The generated unit mirrors the canonical rc.local compatibility unit that some distributions still ship (`Type=forking`, `TimeoutSec=0`, `RemainAfterExit=yes`, `GuessMainPID=no`), so backgrounded commands and slow startups behave correctly. It waits on `network-online.target`, so commands that need actual network connectivity work reliably.

## What it's for

Any small task you want to run once at boot without writing a systemd unit for it:

- starting a personal daemon or script
- applying a hardware tweak (fan curves, LEDs, sysctl one-offs)
- mounting something, poking a GPIO, sending a "server is up" notification
- anything you'd have put in rc.local twenty years ago

## Usage

```sh
sudo ./enable-rc-local.sh
```

Then add your commands to `/etc/rc.local` above the final `exit 0`:

```sh
#!/bin/bash
/usr/local/bin/my-startup-thing &
exit 0
```

Changes take effect on the next boot, or immediately with:

```sh
sudo systemctl restart rc-local.service
```

## Requirements and compatibility

- A systemd-based distribution (Debian, Ubuntu, Fedora, RHEL/Alma/Rocky, Arch, openSUSE, ...). The script checks and refuses to run otherwise.
- Root privileges.
- Non-systemd distributions (Alpine, Devuan, Void, ...) don't need this — they still support rc.local natively.
- Immutable/declarative distributions (NixOS, Fedora Silverblue, MicroOS) are out of scope; use their native mechanisms instead.

Notes:

- `/etc/rc.local` must exit `0` on success, and it is invoked with a `start` argument (sysvinit convention) that can be ignored.
- If the service shows as failed, one of your rc.local commands returned non-zero — check `journalctl -u rc-local.service`.
- Re-running the script is safe: an existing `/etc/rc.local` is never overwritten.
