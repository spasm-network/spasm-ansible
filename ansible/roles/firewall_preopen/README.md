## firewall_preopen Role

### Purpose
Pre-open firewall ports needed for provisioning before SSH hardening and final firewall lockdown. Prevents SSH lockout during setup.

### Key Behaviors
- Installs and starts firewalld (does NOT enable at boot — deferred to `firewall_enable` role)
- Opens HTTP (80) needed for obtaining ssl cert, HTTPS (443),
- Opens SSH ports (default 22 or custom via `new_ssh_port`)
- Uses `ansible.posix.firewalld` module for idempotency — safe to re-run, no duplicate rules
- On Debian: optionally sets `DEBIAN_FRONTEND=noninteractive` and `NEEDRESTART_MODE=a` to avoid interactive prompts
- Validates `new_ssh_port` is numeric and in range (1-65535); defaults to 22 if undefined/empty/0

### Variables
- `new_ssh_port`: SSH port to pre-open (default: 22, or from `NEW_SSH_PORT` env var)
- `set_debian_env`: If true, sets DEBIAN_FRONTEND and NEEDRESTART_MODE on Debian family (default: true)

### Supported Distros
- Debian/Ubuntu
- RHEL/CentOS/Fedora
- SUSE/openSUSE

### Playbook Order
This role must run **before** `sshd_hardening` and **before** `firewall_enable`:

```yaml
- role: firewall_preopen      # Opens 80, 443, SSH port
- role: sshd_hardening        # Hardens SSH (safe, port already open)
- role: firewall_enable       # Enables firewalld, locks down to final state
- role: fail2ban              # Monitoring
