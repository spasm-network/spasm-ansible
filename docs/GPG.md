## GPG

All Spasm commits have been cryptographically signed with GPG since day one to guarantee security. You can verify commits with these steps.

**Note: by default, a full server setup with Ansible includes auto-updates that automatically verify GPG signatures.**

#### Install dependencies

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install -y gnupg

# Fedora/RHEL/CentOS
sudo dnf install -y gnupg2

# openSUSE
sudo zypper install -y gpg2

# Arch
sudo pacman -S --noconfirm gnupg
```

#### Download and import public key

```bash
curl -sL https://git.spasm.network/degenrocket.gpg | gpg --import
curl -sL https://codeberg.org/degenrocket.gpg | gpg --import
curl -sL https://github.com/degenrocket.gpg | gpg --import
```

#### Verify latest commit

```bash
git verify-commit HEAD
```

You should see a "good signature" output:

```bash
gpg: Signature made Tue Apr 20 00:00:00 2026 UTC
gpg:                using EDDSA key 0DEA1743A6742F25CF83A4E519896421F4AE9EA4
gpg: Good signature from "degenrocket <noreply@degenrocket.space>" [unknown]
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 0DEA 1743 A674 2F25 CF83  A4E5 1989 6421 F4AE 9EA4
```
