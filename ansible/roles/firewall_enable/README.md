firewall_enable

What:
- Asserts `new_ssh_port` is defined and is an integer.
- Verifies `new_ssh_port` is present in firewalld permanent config (either as explicit port or via 'ssh' service in public zone).
- Ensures `new_ssh_port`, 80, and 443 are enabled permanently in public zone.
- Removes other permanent TCP ports (does not touch services or rich rules).
- Removes 'ssh' service if `new_ssh_port` is not 22 (prevents port 22 from being open unintentionally).
- Reloads firewalld only if permanent config changed.
- Starts and enables firewalld at boot.

Why:
- Prevents enabling firewall at boot until SSH port is confirmed (avoids lockout).
- Keeps web ports open for Docker/nginx.
- Cleans up stale port entries while preserving services.
- Removes default 'ssh' service when using non-standard port to enforce explicit port control.
- Uses firewalld module for idempotency and safety.

## Required Variables

- `new_ssh_port` (int): The SSH port to verify and preserve (e.g., 2222 or 22).

## Notes

- Assumes `public` zone — modify `zone:` parameter if using a different zone.
- Does not manipulate services, rich rules, or interfaces — only explicit TCP ports and the 'ssh' service (when non-standard port is used).
- No iptables fallback — modern systems use firewalld/nftables.
- If `new_ssh_port` is 22, the 'ssh' service is preserved; if non-standard, it is removed to enforce explicit port control.

## Verification (After Playbook Runs)

Run these commands to verify firewall is correctly configured:

```bash
# Check firewalld is running and enabled at boot
sudo systemctl is-active firewalld && sudo systemctl is-enabled firewalld

# List permanent ports (should include new_ssh_port, 80, 443)
sudo firewall-cmd --permanent --list-ports

# List runtime ports (should match permanent after reload)
sudo firewall-cmd --list-ports

# Verify new SSH port is accessible in runtime config (change to your port)
sudo firewall-cmd --zone=public --query-port=NEW_SSH_PORT/tcp

# Verify HTTP port 80 is accessible in runtime config
sudo firewall-cmd --zone=public --query-port=80/tcp

# Verify HTTPS port 443 is accessible in runtime config
sudo firewall-cmd --zone=public --query-port=443/tcp

# Check nginx is listening on 443
ss -ltnp | grep ':443'

# Test HTTPS connectivity (replace example.com with your domain)
curl -I https://example.com
```
