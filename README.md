WIP: don't use in production yet. If you want to launch an instance now, then deploy using [docker/podman](https://github.com/spasm-network/spasm-docker). Once this repo is ready for prod, there will be a proper instruction and announcement.

# Ansible Server Setup &amp; Hardening Automation

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
- SSH hardening role — backups original configs, idempotently applies secure settings (port, root/password auth, etc.), validates with `sshd -t`, restarts, verifies SSH listens on new port with retries, auto-rolls back on failure, optional root lock (default true), prechecks port/admin user, logs to /var/log/ssh_hardening.log, runs after firewall_preopen and before firewall_enable, supports Debian/RHEL/SUSE.
- firewall_enable — Enables firewalld, verifies `new_ssh_port` is open, ensures 80/443 accessible, removes stale ports, removes default `ssh` service if non-standard port. Runs after `sshd_hardening`.
- nginx_proxy — deploys an HTTP reverse proxy listening on 127.0.0.1:33333 (configurable via nginx_backend_port or HOST_PORT). It renders one shared websocket.conf (includes the websocket map) plus per-site unique upstreams named {{ nginx_site_name }}_backend. ACME challenge location is provided. HTTPS blocks are rendered conditionally using a deterministic certs_present check; if http_redirect_to_https is set but certs are absent the playbook fails. Template rendering is idempotent; websocket map is shared across sites and upstreams are unique per site.
- ssl_certificate — automates Let's Encrypt provisioning via certbot. Obtains certs on first run, then runs `certbot install` every run (idempotent, no re-issue). Primary renewal via cron/systemd; safeguard cron at 4 AM auto-renews if expiring within 7 days. Backs up nginx config before edits; restores on failure. Logs all activity; alerts root if renewal fails. Safe to re-run; fixes config drift.
- container_runtime — installs and validates container runtimes (default: podman) using distro-native packages (apt/dnf/zypper). It detects and enables the correct systemd unit (fails fast if unit files are missing), deploys a minimal /etc/containers/registries.conf for Podman when absent, performs a smoke test, and writes a simple install log. Docker's official repo is intentionally not added by this role; use a separate opt-in step if you need docker-ce.
- app_deployment — clones or updates app repo (hard-resets local changes), writes missing .env keys only (does not overwrite existing values), detects podman/docker, validates and runs compose, and performs a port smoke test; writes run_summary JSON to logs_dir on control machine.
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
│   ├── firewall_enable/       # firewalld setup
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
   - nginx_proxy: installs nginx, deploys HTTP reverse proxy to 127.0.0.1:33333, prepares ACME challenge location, idempotent template + config validation.
   - ssl_certificate: obtains Lets Encrypt certs via `certbot --nginx` on first run (EXPIRING/MISSING), then runs `certbot install` every run to ensure HTTPS block is present (idempotent, does not re-issue certs, preserves certbot's modifications). Re-invokes nginx_proxy role every run to ensure template applied (fixes config drift). Primary renewal via cron/systemd daily (default 3 AM); safeguard cron at 4 AM auto-renews if cert expires within 7 days (gives certbot 23 days to renew first).
   - Backs up nginx config before certbot edits; restores on failure. Logs all activity with timestamps to /var/log/letsencrypt/renewal-check.log; alerts root if renewal fails. Safeguard script uses `flock` to prevent concurrent runs. Safe to re-run; fixes config drift if something breaks.



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





