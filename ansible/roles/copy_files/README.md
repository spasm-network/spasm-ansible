## copy_files role

Purpose
- Copy SSH authorized keys from root into user and Ansible-related files from the installer/root into the managed admin account so it can run maintenance scripts, fetch latest updates from git repo, and rerun full setup if needed.

Features
- Detects user and admin home directories via getent.
- Creates ~/.ssh directories with correct permissions.
- Optionally copies /root/.ssh/authorized_keys into user/admin accounts.
- Optionally copies the spasm-ansible repository (or specified repo path) into the admin home.
- Idempotent: skips copies when files already exist and ownership/permissions match.

Typical checks performed
- Presence of /root/authorized_keys
- Existence of target home directories
- Permission and ownership of created files/directories

Notes
- Ensures SSH keys and repo are owned by the target user (not root).
- Does not overwrite files unless explicitly configured to do so.
