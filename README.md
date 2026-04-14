WIP: don't use in production yet. If you want to launch an instance now, then deploy using [docker/podman](https://github.com/spasm-network/spasm-docker). Once this repo is ready for prod, there will be a proper instruction and announcement.

# Ansible Server Setup &amp; Hardening Automation

DESCRIPTION:
One-script setup for provisioning and hardening a fresh VPS from scratch. Supports 
two modes: (1) local — run directly on the VPS, (2) remote — run from host machine 
via SSH. Fully idempotent with distro modularity (Debian/Ubuntu, RedHat/CentOS/Fedora).

Manager clones repo to target VPS (local mode) or host machine (remote mode), runs server-setup,
and answers prompts for admin password, domain, etc. After playbook completes, entire repo
(including scripts/ and .env) is copied to 'user' and 'admin' accounts on server; in remote
mode, also copied to 'root' for Ansible access. Thus, manager can use scripts from both
user/admin to manage a server.

Includes roles:
- user_and_groups — ensures a managed non-privileged user and a sudo-enabled admin account are present, creates an admin group with a sudoers drop-in, and enforces SSH-key-only access for regular users; idempotent and safe for repeated runs.
- copy_files — copies SSH keys into user and the ansible repo into admin accounts, creating ~/.ssh and preserving ownership and permissions; optional and idempotent.
- system_updates — distro-specific package upgrades + unattended-updates (deb/dnf/zypper), creates /var/run/reboot-required; reboots deferred to admin scripts.
- auto-updates,
- firewall_preopen — opens http (80) for ssl cert, https (443), and ssh ports (default 22 or custom via `NEW_SSH_PORT` env var) using firewalld; installs and starts firewalld but does not enable at boot;
- SSH hardening role — backups original configs, idempotently applies secure settings (port, root/password auth, etc.), validates with `sshd -t`, verifies SSH listens on new port with retries, auto-rolls back on failure, locks root by default (opt-out), pre-checks that {{ user_name }} has SSH keys, logs to /var/log/ssh_hardening.log, runs after firewall_preopen and before firewall_enable, supports Debian/RHEL/SUSE.
- firewall_enable — Enables firewalld, verifies `new_ssh_port` is open, ensures 80/443 accessible, removes stale ports, removes default `ssh` service if non-standard port. Runs after `sshd_hardening`.
- nginx_proxy — deploys an HTTP reverse proxy listening on 127.0.0.1:33333 (configurable via nginx_backend_port or HOST_PORT). It renders one shared websocket.conf (includes the websocket map) plus per-site unique upstreams named {{ nginx_site_name }}_backend. ACME challenge location is provided. HTTPS blocks are rendered conditionally using a deterministic certs_present check; if http_redirect_to_https is set but certs are absent the playbook fails. Template rendering is idempotent; websocket map is shared across sites and upstreams are unique per site.
- ssl_certificate — automates Let's Encrypt provisioning via certbot. Obtains certs on first run, then runs `certbot install` every run (idempotent, no re-issue). Primary renewal via cron/systemd; safeguard cron at 4 AM auto-renews if expiring within 7 days. Backs up nginx config before edits; restores on failure. Logs all activity; alerts root if renewal fails. Safe to re-run; fixes config drift.
- container_runtime — installs and validates container runtimes (default: podman) using distro-native packages (apt/dnf/zypper). It detects and enables the correct systemd unit (fails fast if unit files are missing), deploys a minimal /etc/containers/registries.conf for Podman when absent, performs a smoke test, and writes a simple install log. Docker's official repo is intentionally not added by this role; use a separate opt-in step if you need docker-ce.
- app_deployment — clones or updates app repo (hard-resets local changes), writes missing .env keys only (does not overwrite existing values), detects podman/docker, validates and runs compose, and performs a port smoke test; writes run_summary JSON to logs_dir on control machine.
- fail2ban — installs and configures fail2ban using a per-distro drop-in SSH jail, auto-selects backend and logpath, validates the SSH port, restarts the service via a handler when config changes, and writes a restricted-permission setup audit log; compatible with Debian, RHEL/CentOS/Fedora, and SUSE.

FOLDER STRUCTURE:
.
├── server-setup               # Single entrypoint (local or remote mode)
├── .env                       # Generated at runtime, stores config (gitignored)
├── .gitignore
├── playbook.yml               # Main playbook
├── roles/
│   ├── logging/               # Log variables
│   ├── user_and_groups/       # Create 'user' and 'admin' with sudo
│   ├── copy_files/            # Copy ssh dir to 'user', ansible dir to 'admin'
│   ├── system_updates/        # apt/dnf/zypper upgrades + auto-updates
│   ├── firewall_preopen/
│   ├── sshd_hardening/
│   ├── nginx_proxy/
│   ├── ssl_certificate/       # Let's Encrypt via certbot
│   ├── container_runtime/     # Install container runtime (podman/docker)
│   ├── app_deployment/
│   ├── firewall_enable/
│   └── fail2ban/
└── scripts/                   # Management scripts (copied to 'admin')
    ├── server/
    │   ├── update
    │   ├── reboot
    │   └── cert-renew
    ├── nginx/
    │   ├── restart
    │   └── reload-config
    └── firewall/
        └── status

## KEY NOTES:

### ADMIN_PASSWORD HANDLING:
- Hash immediately in server-setup, never store plaintext
- Store only hash in .env
- Use Ansible `update_password: on_create` for idempotency
- Wipe plaintext from memory after hashing

### IDEMPOTENCY:
- All tasks safe to re-run; .env prompt asks to confirm/change vars
- Admin password only used to manage server (sudo), not app web admin panel
- Existing configs not overwritten unless explicitly changed

### SYSTEM UPDATES:
- idempotent per-distro updates and auto-update config;
- needrestart/dnf-automatic/yast used;
- reboots are deferred (flag file /var/run/reboot-required) and performed only via admin reboot script.

### DISTRO MODULARITY:
- Use `include_vars` + `include_tasks` keyed on `ansible_os_family`
- Example: roles/sshd_hardening/tasks/main.yml includes Debian.yml or RedHat.yml
- vars/ folder contains distro-specific package names, paths, etc.

### LOCAL vs REMOTE MODE (not implemented yet):
- Single server-setup with optional --remote flag (WIP)
- Only difference: inventory generation (localhost vs remote IP)
- Playbook + roles identical for both modes

### SCRIPTS FOLDER:
- Operator can update ansible git repo to get new scripts (from admin or root)

### USAGE:
- Local: git clone repo-url && cd repo-name && bash server-setup
- Remote: bash server-setup --remote --host 1.2.3.4 --key ~/.ssh/id_ed25519
- Scripts: bash ./scripts/user/app/view-logs OR su - admin && bash ./scripts/admin/server/update
- .env or role config: allow opt-out or "auto_reboot: true/false" (default false) 

### SECURITY:
- .env file: chmod 600, gitignored
- SSH keys passed via --key flag (remote mode, not implemented yet)
- no plaintext passwords stored anywhere
- all packages are installed from the distro's default repositories.

### NGINX & SSL:
- nginx_proxy: installs/enables nginx; deploys HTTP reverse proxy to 127.0.0.1:33333; prepares ACME webroot (/var/www/certbot) and HTTP-01 location; renders idempotent site templates, runs `nginx -t` and reloads on success; HTTPS disabled until certs_present is true.
- ssl_certificate: runs `certbot --nginx` on first run (EXPIRING/MISSING); each run re-invokes nginx_proxy and runs `certbot install --nginx` (idempotent, preserves certbot changes) to ensure HTTPS block; daily `certbot renew` (default 03:00) with a 04:00 safeguard that renews if cert expires within 7 days.
- Ops: backup nginx site config before certbot edits and restore on failure; safeguard uses `flock`; logs renewal-checks to /var/log/letsencrypt/renewal-check.log and alerts root on failure; safe to re-run and fixes config drift.

###  USERS:
- root owns infrastructure (initial setup, auto-updates, no ssh)
- admin owns manual interventions (sudo, manual updates, no ssh)
- user runs app with podman (no sudo, ssh login allowed)



FINAL SERVER STRUCTURE AFTER SETUP:

root (initial setup only, minimal access after)
├── .ssh/
│   └── authorized_keys (Ansible SSH key for remote mode)
└── spasm-ansible/
    ├── ansible/
    ├── scripts/
    ├── .env
    ├── import-gpg
    ├── verify-repo
    ├── init.sh
    └── server-setup

user (runs docker/podman app, no sudo)
├── .ssh/
│   └── authorized_keys (manager SSH key)
└── spasm-docker/ (from spasm-docker git repo)
    ├── backups/
    ├── scripts/
    ├── .env
    ├── .env.example
    └── docker-compose.yml

admin (infrastructure management, sudo access, no ssh)
└── spasm-ansible/
    ├── ansible/
    ├── scripts/
    ├── .env
    ├── import-gpg
    ├── verify-repo
    ├── init.sh
    └── server-setup

Other notes:
- root: used for initial server setup then ssh disabled, but runs server-setup script periodically for auto-updates; operator SSHs as 'user' (no password) and uses `su - admin` + password for manual interventions with sudo.
- Preflight checks in server-setup: verify network connectivity, disk space (>X GB), supported distro, and local Ansible >= required version. (todo) 
- Dry-run: server-setup supports a `--check` mode that runs ansible-playbook `--check`. 
- Post-run stamp/logs: after success write timestamp + minimal JSON summary into repo folder logs (ansible/logs/last_run.json) and rotate logs.  
- nginx: templates rendered idempotently; before reload run nginx -t && systemctl reload nginx; on test fail keep previous config and log error. Ensure reruns are safe.  
- Defer reboots for auto-updates (optional): install security updates but defer reboots; create /var/run/pending-reboot when reboot required; scripts/admin/server/reboot performs safe reboot on admin confirmation.  
- Firewall: ensure Ansible SSH rule present before enabling firewall to avoid lockout.  


## Full server auto-updates with Ansible

Auto-updates with Ansible are managed with scripts (not roles), but a role adds a cron job for auto-updates to execute.

`server-setup` script (Main Orchestrator)

1. Call `import-gpg` (ensure GPG key in keyring for root, admin, and user)
2. Call `fetch-verify-repo` (clone to temp, verify, swap if good)
3. Call `init.sh` (with or without `--auto-update`)

`import-gpg` script

- Installs GPG (idempotent, distro-aware)
- Imports embedded GPG public key into keyrings:
  - root: always (required for cron auto-updates and signature verification)
  - admin: if running as root or via sudo from admin (required for manual repo verification)
  - user: if running as root or via sudo (required for app repo signature verification)
- Non-fatal if admin/user accounts do not exist yet (e.g., first run before `user_and_groups` role)
- Uses `runuser` to switch users (no sudoers dependency)
- Sets owner trust to "ultimate" (5) on imported keys so git verify-tag works without warnings
- Idempotent: `gpg --import` skips already-imported keys


`fetch-verify-repo` script

Fetches latest (or specified) semver git tag, verifies GPG signatures, and atomically swaps production repo.

**Verification steps:**
1. Acquires lock to prevent concurrent runs
2. Clones repo to secure temp directory (`/var/tmp/fetch-verify-repo-<timestamp>`)
3. Fetches all tags and identifies latest semver tag (v1.2.3 format)
4. Skips if production repo already at target tag (idempotent)
5. Detects tag type: annotated (tag object) or lightweight (commit)
6. Verifies GPG signature on tag (annotated) or commit (lightweight)
7. Extracts signer key fingerprint and checks against allowlist
8. Verifies GPG signature on commit the tag points to (defense in depth)
9. Checks out verified tag in temp directory
10. Final verification: ensures current commit is signed
11. Atomically swaps temp repo into production (with cross-device fallback)
12. Sets secure ownership (root:root) and permissions (750 dirs, 640 files, 750 scripts)
13. On success: deletes backup, cleans up temp
14. On failure: restores backup from temp, keeps temp for forensic debugging

**Keyring & allowlist:**
- Uses caller's GPG keyring (`~/.gnupg`); ensure `import-gpg` has been run first
- Compares signer fingerprint against `ALLOWED_KEY_FPS` array (40-char hex, case-normalized)
- Fails if signature is invalid or signer not in allowlist

**Usage:**
```bash
bash scripts/fetch-verify-repo.sh              # Fetch and verify latest tag
bash scripts/fetch-verify-repo.sh --tag v1.2.5 # Fetch and verify specific tag
sudo bash scripts/fetch-verify-repo.sh         # Run as admin via sudo
```

`init.sh`

- Takes `--auto-update` flag (optional)
- If `--auto-update`: read vars from `.env` (non-interactive)
- If no flag: prompt operator for vars
- Run ansible playbook locally
- Log everything

### Operator Workflow

Day 1 (Setup from root):
```
1. SSH into new VPS as root
2. git clone https://github.com/spasm-network/spasm-ansible.git ~/spasm-ansible/
3. cd ~/spasm-ansible
4. bash server-setup
   - Calls import-gpg (imports key into root, admin, user keyrings; sets owner trust)
   - Calls fetch-verify-repo (verifies repo using root's keyring; atomically swaps)
   - Calls init.sh (runs playbook, creates admin/user accounts)
5. Wait for completion
6. Server is live
```

Day 4, 7, 10, etc. (Automatic):
- Cron runs from root: `bash ~/spasm-ansible/server-setup --auto-update`
  - Calls import-gpg (idempotent; key already present)
  - Calls fetch-verify-repo (verifies latest tag using root's keyring; skips if already at tag)
  - Calls init.sh (runs playbook with non-interactive vars from .env)
- All autonomous, no operator interaction
- On verification failure: keeps temp directory for debugging, restores backup, exits with error
- On success: logs to `/var/log/spasm-ansible/fetch-verify-repo.log`
