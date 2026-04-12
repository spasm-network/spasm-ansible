## user_and_groups role

Purpose
- Create a non-privileged user and an admin account (with sudo), plus an admin group and sudoers entry.

Features
- Ensures admin group exists and is allowed in sudoers (/etc/sudoers.d/admin_group).
- Ensures regular user exists with home directory and password locked (SSH keys only).
- Ensures admin user and group exist, adds admin to sudo and admin groups, and sets password from a hashed value.
- Idempotent and safe to re-run.

Variables (defaults)
- user_name: user
- admin_name: admin
- admin_password_hash: hashed password string (use a pre-hashed value; role expects hash)

Notes
- The role locks the regular user password to enforce SSH-key-only access by default.
- Passwords should be hashed before passing to Ansible, e.g.:

```bash
ADMIN_PASSWORD_HASH=$(openssl passwd -6 "$ADMIN_PASSWORD")
```
