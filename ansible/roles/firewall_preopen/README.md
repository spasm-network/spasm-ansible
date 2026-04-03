# roles/firewall_preopen/README.md

## firewall_preopen Role

### Purpose
Pre-open the SSH port in the firewall **before** SSH hardening is applied. This prevents lockout during the hardening process.

### Key Behaviors
- **Installs** firewall package (ufw, firewalld, or iptables).
- **Adds SSH port rule** (permanent for firewalld, idempotent for ufw).
- **Does NOT start or enable** the firewall service — that is deferred to `firewall_enable` role, which runs after SSH hardening completes.
- **Idempotent**: safe to re-run; existing rules are not duplicated.

### Variables
- `new_ssh_port`: SSH port to pre-open (default: 22)
- `set_debian_env`: If true, sets DEBIAN_FRONTEND and NEEDRESTART_MODE on Debian family (default: true)
- `enable_iptables_fallback`: If true, enables iptables fallback branch (default: false)

### Supported Distros
- Debian/Ubuntu (uses UFW)
- RHEL/CentOS/Fedora (uses firewalld)
- SUSE (uses firewalld)

### Playbook Order
This role must run **before** `sshd_hardening` and **before** `firewall_enable`:
```yaml
- role: firewall_preopen
- role: sshd_hardening
- role: firewall_enable
- role: fail2ban
