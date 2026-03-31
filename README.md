# PROJECT: Ansible Server Setup and Hardening Automation

DESCRIPTION:
One-script setup for provisioning and hardening a fresh VPS from scratch. Supports 
two modes: (1) local — run directly on the VPS, (2) remote — run from host machine 
via SSH. Fully idempotent with distro modularity (Debian/Ubuntu, RedHat/CentOS/Fedora).

Manager clones repo to target VPS (local mode) or host machine (remote mode), runs init.sh,
and answers prompts for admin password, domain, etc. After playbook completes, entire repo
(including scripts/ and .env) is copied to 'user' and 'admin' accounts on server; in remote
mode, also copied to 'root' for Ansible access. Thus, manager can use scripts from both
user/admin to manage a server.

Includes roles:
- user/admin setup,
- system_updates — distro-specific package upgrades + unattended-updates (deb/dnf/zypper), creates /var/run/reboot-required; reboots deferred to admin scripts.
- auto-updates,
- SSH hardening,
- firewall,
- container_runtime — installs and validates container runtimes (default: podman) using distro-native packages (apt/dnf/zypper). It detects and enables the correct systemd unit (fails fast if unit files are missing), deploys a minimal /etc/containers/registries.conf for Podman when absent, performs a smoke test, and writes a simple install log. Docker's official repo is intentionally not added by this role; use a separate opt-in step if you need docker-ce.
- SSL cert,
- Nginx reverse proxy,
- app deployment,
- management scripts.

FOLDER STRUCTURE:
.
├── init.sh                    # Single entrypoint (local or remote mode)
├── .env                       # Generated at runtime, stores config (gitignored)
├── .gitignore
├── ansible.cfg
├── playbook.yml               # Main playbook
├── docker.yml                 # Main playbook
├── inventory/
│   └── hosts.ini              # Generated dynamically by init.sh
├── roles/
│   ├── logging/               # Log variables
│   ├── user_and_groups/       # Create 'user' and 'admin' with sudo
│   ├── copy_files/            # Copy ansible and ssh folders to 'admin' and 'user'
│   ├── system_updates/        # apt/dnf/zypper upgrades + auto-updates
│   ├── nginx_proxy/           # Reverse proxy config
│   ├── sshd_hardening/        # SSH config
│   ├── firewall/              # UFW/firewalld setup
│   ├── container_runtime/     # Install container runtime (podman/docker)
│   ├── ssl_certificate/       # Let's Encrypt via acme.sh/certbot (staging→prod flow)
│   └── app_deployment/        # Clone/run app in container
├── group_vars/
│   └── all.yml                # Shared variables
└── scripts/                   # Management scripts (copied to both 'user' and 'admin')
    ├── user/                  # Runnable as 'user' (no sudo)
    │   ├── app/
    │   │   ├── view-logs
    │   │   └── view-status
    │   └── monitoring/
    │       ├── disk-usage
    │       └── network-status
    └── admin/                 # Runnable as 'admin' (su - admin first)
        ├── server/
        │   ├── update
        │   ├── reboot
        │   └── cert-renew
        ├── nginx/
        │   ├── restart
        │   └── reload-config
        └── firewall/
            └── status

KEY NOTES:

1. ADMIN_PASSWORD HANDLING:
   - Hash immediately in init.sh, never store plaintext
   - Store only hash in .env (safe)
   - Use Ansible `update_password: on_create` for idempotency
   - Wipe plaintext from memory after hashing

2. IDEMPOTENCY:
   - All tasks safe to re-run; .env prompt asks to confirm/change vars
   - Admin password only set on first user creation
   - Admin password only used to manage server (sudo), not app web admin panel
   - Existing configs not overwritten unless explicitly changed

3. SYSTEM UPDATES: idempotent per-distro updates and auto-update config; needrestart/dnf-automatic/yast used; reboots are deferred (flag file /var/run/reboot-required) and performed only via admin reboot script.

4. DISTRO MODULARITY:
   - Use `include_vars` + `include_tasks` keyed on `ansible_os_family`
   - Example: roles/sshd_hardening/tasks/main.yml includes Debian.yml or RedHat.yml
   - vars/ folder contains distro-specific package names, paths, etc.

5. LOCAL vs REMOTE MODE:
   - Single init.sh with optional --remote flag
   - Only difference: inventory generation (localhost vs remote IP)
   - Playbook + roles identical for both modes

6. SCRIPTS FOLDER:
   - Nested structure: scripts/user/ (no sudo) and scripts/admin/ (requires su - admin)
   - Self-documenting: manager knows immediately which scripts need elevation
   - Manager can update ansible git repo to get new scripts (from user and admin)

7. USAGE:
   Local:  git clone repo-url && cd repo-name && bash init.sh
   Remote: bash init.sh --remote --host 1.2.3.4 --key ~/.ssh/id_ed25519
   Scripts: bash ./scripts/user/app/view-logs  OR  su - admin && bash ./scripts/admin/server/update
   .env or role config: allow opt-out or "auto_reboot: true/false" (default false) 

8. SECURITY:
   - .env file: chmod 600, gitignored
   - SSH keys passed via --key flag (remote mode)
   - No plaintext passwords stored anywhere

9. NGINX & SSL:
   - nginx_proxy: installs nginx, deploys HTTP reverse proxy to 127.0.0.1:33333,
     prepares ACME challenge location, idempotent template + config validation.
   - ssl_certificate: (next) obtains Let's Encrypt certs (staging→prod), updates
     nginx config to terminate TLS, adds HTTP→HTTPS redirect.




FINAL SERVER STRUCTURE AFTER SETUP:

root (initial setup only, minimal access after)
├── .ssh/
│   └── authorized_keys (Ansible SSH key for remote mode)
└── ansible/
    ├── scripts/
    ├── .env
    └── site.yml

user (runs docker/podman app, no sudo)
├── .ssh/
│   └── authorized_keys (manager SSH key)
├── docker/ (from docker git repo)
│   ├── backups/
│   ├── scripts/
│   ├── .env
│   └── docker-compose.yml
└── ansible/
    ├── scripts/user/
    ├── .env
    └── site.yml

admin (infrastructure management, sudo access, no ssh)
└── ansible/
    ├── scripts/admin/
    ├── .env
    └── site.yml

Other notes:
- root: used only for initial install then disabled; manager SSHs as 'user' (no password) and uses su - admin + password for sudo.
- Preflight checks in init.sh: verify network connectivity, disk space (>X GB), supported distro, and local Ansible >= required version.  
- Dry-run: init.sh supports a --check mode that runs ansible-playbook --check.  
- Post-run stamp/logs: after success write timestamp + minimal JSON summary into repo folder logs (ansible/logs/last_run.json) and rotate logs.  
- nginx: templates rendered idempotently; before reload run nginx -t && systemctl reload nginx; on test fail keep previous config and log error. Ensure reruns are safe.  
- SSL: use either certbot with lets encrypt without email address, or use staging→production ACME flow (acme.sh preferred for bootstrap automation); run staging first to validate automation. Store keys with 600 perms; implement expiry monitoring since email will be omitted.  
- Defer reboots for auto-updates (optiona): install security updates but defer reboots; create /var/run/pending-reboot when reboot required; scripts/admin/server/reboot performs safe reboot on admin confirmation.  
- Firewall: ensure Ansible SSH rule present before enabling firewall to avoid lockout.  
