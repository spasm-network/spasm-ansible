# sshd_hardening Role

## Purpose
Harden SSH configuration with safety-first approach: backup → validate → restart → verify listening. Includes rollback on failure.

## Key Behaviors
- Installs openssh server and utilities.
- Backs up original sshd_config with timestamp.
- Backs up extra SSH config files from `/etc/ssh/sshd_config.d/` and removes them (preserved in backup dir).
- Applies hardening settings via lineinfile (idempotent).
- Validates sshd_config syntax with `sshd -t`.
- Optionally locks root account (`lock_root: true` by default).
- Restarts SSH service only if configuration changed.
- Verifies SSH is listening on the configured port using `ss`.
- On failure: restores backups, restarts SSH, logs failure, and fails play.

## Variables (defaults)
- `new_ssh_port`: SSH port (default: 22)
- `permit_root_login`: PermitRootLogin (default: "no")
- `password_authentication`: PasswordAuthentication (default: "no")
- `permit_empty_password`: PermitEmptyPasswords (default: "no")
- `x11_forwarding`: X11Forwarding (default: "no")
- `max_auth_tries`: MaxAuthTries (default: 3)
- `max_sessions`: MaxSessions (default: 5)
- `client_alive_interval`: ClientAliveInterval (default: 300)
- `client_alive_count_max`: ClientAliveCountMax (default: 2)
- `compression`: Compression (default: "no")
- `tcp_keep_alive`: TCPKeepAlive (default: "yes")
- `log_level`: LogLevel (default: "VERBOSE")
- `lock_root`: (default: true) make root password-locked after hardening
- `ssh_hardening_log`: path to written summary log

## Supported Distros
- Debian/Ubuntu (service: ssh)
- RHEL/CentOS/Fedora (service: sshd)
- SUSE (service: sshd)

## Playbook Order
This role must run after `firewall_preopen` and before `firewall_enable`:
```yaml
- role: firewall\_preopen
- role: sshd\_hardening
- role: firewall\_enable
- role: fail2ban
```

## Safety Features
1. Backup before changes using a timestamped copy and recorded path.
2. Syntax validation with `sshd -t` before restart.
3. Verify listening on the new port using `ss` socket filter.
4. Deterministic backup/restore of extra drop-in files (saved under `extra_ssh_config_backup_dir`).
5. Best-effort check and warning if no non-root user with authorized_keys is present.
6. Optional root locking via `lock_root` variable.
7. Logging summary to `/var/log/ssh_hardening.log`.

## Troubleshooting
- Check the backup path recorded in `/var/log/ssh_hardening.log`.
- SSH logs:
  - Debian: `/var/log/auth.log`
  - RedHat: `/var/log/secure`
- Manual checks:
  - `sshd -t`
  - `ss -ltnp | grep :<port>`
  - Inspect backed up drop-in files in `/etc/ssh/sshd_config.d.bak/`
