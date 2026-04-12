Purpose
- Install and configure fail2ban across Debian, RHEL, and SUSE families using a safe drop-in approach.

Features
- Installs fail2ban via apt/dnf/zypper per distribution.
- Places SSH jail as a drop-in under /etc/fail2ban/jail.d/ to avoid overwriting existing jail.local.
- Detects distro log path (/var/log/secure for RHEL, /var/log/auth.log otherwise).
- Chooses backend based on init system (systemd vs auto).
- Validates SSH port range before applying configuration.
- Uses a handler to restart fail2ban only when config changes.
- Writes a restricted-permission setup log at /var/log/fail2ban-setup.log.
- Idempotent and safe to run repeatedly.

Usage
- Set ssh_port variable when invoking the role (default: 22).
  Example:
  ansible-playbook site.yml -e "ssh_port=2222"

Files
- tasks/main.yml: playbook tasks (or include playbook.yml if used as standalone).
- templates/10-sshd.local.j2: fail2ban drop-in template.

Notes
- The role does not modify existing /etc/fail2ban/jail.local files.
- Consider adding checks to verify sshd is listening on the configured port if you change SSH port remotely.

Manual tests

```bash
# verify fail2ban service is running
sudo systemctl status fail2ban --no-pager

# check sshd jail status and banned IPs
sudo fail2ban-client status sshd
sudo fail2ban-client get sshd banned

# validate the drop-in file was written and contains expected values
sudo cat /etc/fail2ban/jail.d/10-sshd.local

# test fail2ban log and auth log for recent ban/unban events
sudo tail -n100 /var/log/fail2ban.log /var/log/auth.log 2>/dev/null || sudo tail -n100 /var/log/secure 2>/dev/null

# simulate a failed SSH auth (from a test client) and watch for ban (run on test client)
# (replace user@host and run from a different IP than admins)
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no user@host exit || true
# then on server, watch for ban event
sudo tail -F /var/log/fail2ban.log
```

Additional tests

```bash
# show current public IP seen by server (check recent auth logs for your IP)
sudo grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' /var/log/auth.log /var/log/secure 2>/dev/null | tail -n200

# check fail2ban jail status and banned list (you already ran; repeats for copy/paste)
sudo fail2ban-client status sshd
sudo fail2ban-client get sshd banned

# search fail2ban and auth logs for bans/unban events and your IP (replace <your-ip> if known)
sudo grep -iE 'Ban|Unban|banned' /var/log/fail2ban.log /var/log/auth.log /var/log/secure 2>/dev/null | tail -n200
sudo grep -i '<your-ip>' /var/log/auth.log /var/log/secure /var/log/fail2ban.log 2>/dev/null || echo "no hits for <your-ip>"

# if you don’t know your client IP, fetch it from an external service (run locally) and then search logs
curl -s https://ifconfig.co
# then replace <your-ip> above and re-run the grep

# optionally unban an IP (replace 1.2.3.4 with the IP to unban)
sudo fail2ban-client set sshd unbanip 1.2.3.4
```
