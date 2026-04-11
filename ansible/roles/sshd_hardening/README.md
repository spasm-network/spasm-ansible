# sshd_hardening Role

## Purpose
Harden SSH configuration with safety-first approach: backup → create hardening drop-in → validate → verify → lock root. Includes rollback on failure.

## Key Behaviors
- Installs openssh server and utilities.
- Ensures `/etc/ssh/sshd_config` includes `/etc/ssh/sshd_config.d/*.conf` (idempotent).
- Backs up original `sshd_config` with timestamp to `{{ sshd_backup_dir }}`.
- Backs up provider drop-in files to `{{ extra_ssh_config_backup_dir }}` (preserved for reference; not modified).
- Verifies that `{{ user_name }}` has SSH keys (only SSH entry point after root is locked).
- Detects dangerous provider directives (PermitRootLogin variants, PasswordAuthentication, PermitEmptyPasswords) and warns.
- Detects Match blocks in provider drop-ins and warns (may have different scope).
- Detects cloud-init presence and warns about potential provider regeneration.
- Creates `/etc/ssh/sshd_config.d/99-hardening.conf` with hardened settings (overrides provider files via lexicographic precedence).
- Duplicates critical settings (Port, PermitRootLogin, PasswordAuthentication) in main `sshd_config` for redundancy.
- Validates sshd_config syntax with `sshd -t`.
- Verifies SSH is listening on the configured port using `wait_for` and `ss`.
- Validates port via `sshd -T` (non-network check).
- Verifies SSH host keys exist.
- Tests SSH connectivity with runtime connection test before locking root.
- Applies SELinux context if available.
- Optionally locks root account (`lock_root: true` by default).
- On failure: restores backups, removes hardening drop-in, restarts SSH, logs failure, and fails play.

## Variables (defaults)
- `user_name`: Non-root user for SSH access (default: "user", can be set via `USER_NAME` environment variable). **This is the only user that can SSH in after root is locked.**
- `new_ssh_port`: SSH port (default: 22, can be set via `NEW_SSH_PORT` environment variable)
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
- `lock_root`: (default: true) lock root account password after hardening (opt-out if needed)
- `sshd_backup_dir`: directory for timestamped backups (default: /etc/ssh/backups)
- `ssh_hardening_log`: path to written summary log (default: /var/log/ssh_hardening.log)

## Supported Distros
- Debian/Ubuntu (service: ssh)
- RHEL/CentOS/Fedora (service: sshd)
- SUSE (service: sshd)

## SSH Access Model
After this role completes:
- **SSH access:** Only available via `{{ user_name }}` (no password, SSH key required)
- **Root:** Locked (PermitRootLogin no + password_lock yes)
- **Admin access:** Use `su - admin` from `{{ user_name }}` if needed

**Critical:** `{{ user_name }}` must have SSH keys in `~/.ssh/authorized_keys` before this role runs, or you will be locked out.

## VPS Provider Handling
Many VPS hosting providers (Linode, DigitalOcean, Vultr, AWS, etc.) inject custom SSH configs into `/etc/ssh/sshd_config.d/` that can override hardening settings (e.g., `PermitRootLogin yes`, `PasswordAuthentication yes`).

This role handles provider overrides safely:
- **Backs up** provider drop-in files to `{{ extra_ssh_config_backup_dir }}` for reference and audit trail.
- **Does not modify** provider files (preserves provider tooling compatibility).
- **Creates** `/etc/ssh/sshd_config.d/99-hardening.conf` with hardened directives.
- **Overrides** provider settings via lexicographic precedence (99 > provider files).
- **Detects** dangerous directives in provider files and warns (informational only).
- **Detects** Match blocks in provider files and warns (may have different scope than global directives).
- **Detects** cloud-init presence and warns about potential provider regeneration on reboot/updates.

If provider tooling regenerates drop-ins on reboot or updates, re-run this role to reapply hardening.

### Known Limitations
- **Match blocks:** Provider drop-ins may contain Match blocks with different scope than global directives in 99-hardening.conf. Manual review may be required.
- **Provider regeneration:** Some cloud/provider agents may recreate drop-in files. Re-run this role after provider changes to reapply.
- **Backup accumulation:** Timestamped backups are created per run. Operators should periodically clean up old backups to bound disk usage (optional housekeeping task).
- **Localhost connectivity test:** SSH connectivity test uses `localhost`; if SSH is firewalled or in a network namespace, test may pass locally but fail externally. External connectivity is the responsibility of the firewall role.

## Playbook Order
This role must run after `firewall_preopen` and before `firewall_enable`:
```yaml
- role: firewall_preopen
- role: sshd_hardening
- role: firewall_enable
- role: fail2ban
```

## Safety Features
1. **Pre-flight checks:** Verify `{{ user_name }}` exists and has SSH keys before proceeding.
2. Backup before changes using timestamped copies (recorded path in logs).
3. Syntax validation with `sshd -t` before restart.
4. Port validation via `sshd -T` (non-network check).
5. Verify listening on the new port using `wait_for` (robust port check).
6. SSH host key existence check (fail if missing).
7. Runtime SSH connectivity test before locking root.
8. Provider drop-in files are preserved and backed up (not modified).
9. Dangerous provider directives and Match blocks are detected and warned (informational).
10. Cloud-init presence is detected and warned (provider may regenerate configs).
11. High-precedence hardening drop-in (`99-hardening.conf`) overrides provider settings.
12. SELinux context applied if available.
13. Root locking only after all verification passes.
14. Logging summary appended to log file (preserves history with per-step verification results).
15. Comprehensive rollback on failure: restore backups, remove drop-in, restart SSH, log failure.

## Troubleshooting

### Check Logs
- Role summary log: `{{ ssh_hardening_log }}` (appends on each run, includes per-step verification results)
- SSH service logs:
  - Debian: `/var/log/auth.log`
  - RedHat: `/var/log/secure`

### Manual Verification
```bash
# Validate sshd_config syntax
sshd -t

# Check effective configuration
sshd -T | grep port

# Verify port is listening
ss -ltnp | grep :{{ new_ssh_port }}

# Test SSH connectivity
ssh -p {{ new_ssh_port }} {{ user_name }}@localhost

# Inspect hardening drop-in
cat /etc/ssh/sshd_config.d/99-hardening.conf

# Check provider drop-in backups
ls -la /etc/ssh/sshd_config.d.bak/

# Check main config backups
ls -la /etc/ssh/backups/

# Verify SSH host keys
ls -la /etc/ssh/ssh_host_*_key
```

### Common Issues

**SSH fails to listen on new port:**
- Check `/var/log/auth.log` (Debian) or `/var/log/secure` (RedHat) for errors
- Run `sshd -t` to validate syntax
- Verify port is not in use: `ss -ltnp | grep :{{ new_ssh_port }}`
- Check if firewall is blocking the port (firewall_enable role should handle this)

**Role fails: "user '{{ user_name }}' has no SSH keys":**
- Add SSH public key to `{{ user_name }}`'s home directory: `~{{ user_name }}/.ssh/authorized_keys`
- Ensure file permissions: `chmod 600 ~/.ssh/authorized_keys` and `chmod 700 ~/.ssh/`
- Re-run this role after keys are added

**Locked out after role completes:**
- Ensure `{{ user_name }}` has SSH keys before running with `lock_root: true`
- Role fails early if no keys found (prevents lockout)
- If you're already locked out, restore from backup: `cp /etc/ssh/backups/sshd_config.*.bak /etc/ssh/sshd_config && systemctl restart ssh`

**Provider drop-in files regenerated after role run:**
- Provider tooling may recreate drop-ins on reboot or updates
- Re-run this role to reapply hardening
- Consider running this role from your auto-update pipeline after reprovision events

**Match blocks causing unexpected behavior:**
- Review backed-up provider drop-in files in `{{ extra_ssh_config_backup_dir }}`
- Match blocks have different scope; global directives in 99-hardening.conf may not override them
- Manual editing of provider files may be required

**SELinux denials:**
- Run `restorecon -v /etc/ssh/sshd_config.d/99-hardening.conf` to restore context
- Check SELinux audit logs: `ausearch -m avc | grep sshd`

**SSH host keys missing:**
- Role warns if no host keys found and fails verification
- Regenerate host keys: `ssh-keygen -A` (as root)
- Re-run this role after keys are generated

### Backup Recovery

If SSH hardening fails and you need to restore:

```bash
# List available backups
ls -la /etc/ssh/backups/

# Restore a specific backup
sudo cp /etc/ssh/backups/sshd_config.20250412T120530Z.bak /etc/ssh/sshd_config

# Validate and restart
sudo sshd -t
sudo systemctl restart ssh  # or sshd on RedHat/SUSE
```

## Idempotency
This role is fully idempotent:
- Repeated runs with the same variables produce no changes
- Configuration changes are detected and applied only when needed
- Backups are created per run (timestamped for uniqueness)
- Logs are appended (preserving history)
- Per-step verification results are logged for audit trail

## Example Playbook

```yaml
- hosts: all
  roles:
    - role: firewall_preopen
    - role: sshd_hardening
      vars:
        user_name: "user"
        new_ssh_port: 2222
        lock_root: true  # Only set to true after verifying {{ user_name }} has SSH keys
    - role: firewall_enable
    - role: fail2ban
```

## Example with Environment Variables

```bash
export USER_NAME=user
export NEW_SSH_PORT=2222
ansible-playbook playbook.yml
```

## Requirements
- `{{ user_name }}` must exist and have SSH keys in `~/.ssh/authorized_keys` before this role runs
- SSH service must be installed (role installs it if missing)
- Root access (become: true) required to modify SSH config and lock root account


## Manual tests

```bash
# Test user SSH access (should work)
ssh -p 22 user@your-vps-ip "echo SSH_OK"

# Test root SSH access
# (should fail with "Permission denied" or "too many authentication failures")
ssh -p 22 root@your-vps-ip "echo SSH_OK"

# Verify hardening applied from admin or root
sudo sshd -T | grep -E "^(permitrootlogin|passwordauthentication|port)"
```

## Enable root login for testing

```
# WARNING: Only for local testing. Do NOT use in production unless you understand the security implications.
sudo usermod -p '!' root  # Unlock root password
sudo sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart ssh
# After testing, re-lock:
sudo usermod -p '*' root
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart ssh
```
