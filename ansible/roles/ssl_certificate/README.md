# SSL Certificate Role

Automates Let's Encrypt certificate provisioning using certbot and manages nginx configuration, renewal, and safeguards.

## Architecture & Workflow

### Initial Certificate Provisioning (EXPIRING/MISSING)
1. **Backup nginx config** before any certbot changes (safety net).  
2. **Run `certbot --nginx`** to obtain cert and modify nginx config (adds HTTPS block, HTTP→HTTPS redirect).  
3. **Test nginx config** after certbot edits; restore backup if test fails.  
4. **Reload nginx** to activate new config.

### Certificate Maintenance (Every Run)
1. **Re-invoke nginx_proxy role** to ensure HTTPS block is present with correct cert paths (idempotent, fixes config drift).  
2. **Run `certbot install --nginx`** to ensure HTTPS block is installed (idempotent, does NOT re-issue cert, preserves certbot's modifications).  
3. **Test and reload nginx** if install succeeds.

Why this approach:
- `certbot --nginx` modifies config directly and adds certbot-managed comments/markers.  
- Re-invoking `nginx_proxy` ensures our template is applied (fixes drift if something breaks).  
- `certbot install` ensures HTTPS block exists without re-issuing certs (safe to run every time).  
- Both are idempotent: re-running doesn't break anything.

### Renewal (Automatic via Cron/Systemd)
1. **Primary renewal**: systemd timer or cron job runs `certbot renew` daily (default 3 AM).  
2. **Safeguard renewal**: separate cron job at 4 AM checks if cert expires within 7 days; if yes, runs `certbot renew` with `--deploy-hook` to reload nginx.  
3. **Verification**: safeguard logs success/failure; alerts root if renewal fails.

Why dual renewal:
- Certbot's default renewal window is 30 days before expiry.  
- Safeguard waits until 7 days left, giving certbot 23 days to renew by itself.  
- If renewal fails, safeguard catches it and alerts before cert expires.

## Key Behaviors

- **Idempotent:** safe to re-run; skips cert issuance if existing cert has >30 days remaining.  
- **Nginx-safe:** backs up config before certbot edits; restores if nginx test fails.  
- **Fast-fail on fatal errors:** rate limits, auth errors, account problems fail immediately (no retry).  
- **Transient error retry:** network/temporary errors retry once.  
- **Preserves certbot modifications:** `certbot install` doesn't overwrite certbot's comments/markers (important for renewal tracking).  
- **Automatic nginx reload:** safeguard renewal uses `--deploy-hook` to reload nginx after cert renewal.  
- **Concurrent run prevention:** safeguard script uses flock to prevent overlapping executions.  
- **Portable:** uses `openssl x509 -checkend` (works on GNU/BSD/macOS); absolute paths for cron environment.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ssl_domain` | `{{ lookup('env','DOMAIN_NAME') or '' }}` | Primary domain (required; set via DOMAIN_NAME env var) |
| `ssl_subdomains` | `[]` | List of subdomains or hostnames; supports both bare labels (www, api) and full domains (app.example.com) |
| `ssl_enable_http_to_https_redirect` | `true` | Enable HTTP→HTTPS redirect via certbot (`--redirect`) |
| `ssl_renewal_hour` | `3` | Hour for daily renewal cron job (if no systemd timer) |
| `ssl_cert_path` | `/etc/letsencrypt/live/{{ ssl_domain }}` | Certificate live path |
| `ssl_nginx_conf` | `/etc/nginx/sites-available/{{ nginx_site_name }}` | Path to nginx site file to back up |
| `certbot_webroot` | `/var/www/html` | Webroot directory (not used by --nginx but kept for compatibility) |
| `ssl_cert_name` | `{{ ssl_domain }}` | Cert name passed to certbot; defaults to ssl_domain |

## Logging & Monitoring

- **Certificate details:** `/var/log/letsencrypt/last_cert.json` — expiry date, domains, redirect status (updated every run).  
- **Renewal logs:** `/var/log/letsencrypt/renew.log` — primary renewal cron output.  
- **Safeguard logs:** `/var/log/letsencrypt/renewal-check.log` — safeguard checks and renewal attempts (timestamped, includes domain).  
- **Email alerts:** root receives alert if safeguard renewal fails (if mail/MTA available).

## Renewal Safeguard Script

Deployed to `/usr/local/bin/certbot-renewal-safeguard.sh` and runs daily at 4 AM (if no systemd timer).

Logic:
1. Check if cert expires within 7 days.  
2. If yes, run `certbot renew --deploy-hook "systemctl reload nginx"` (reloads nginx after renewal).  
3. Verify renewal succeeded (check if cert now valid for >30 days).  
4. Log success or alert root if renewal failed.  
5. Use flock to prevent concurrent runs (safe if both systemd-timer and cron exist).

Why 7-day threshold:
- Certbot renews starting at 30 days before expiry.  
- Safeguard waits until 7 days, giving certbot 23 days to renew.  
- If renewal fails, safeguard catches it 7 days before expiry (time to investigate).

## Operational Notes

- **First run:** if cert missing, certbot obtains it and modifies nginx config.  
- **Subsequent runs:** cert is valid, `certbot install` ensures HTTPS block present (no re-issue).  
- **Renewal:** cron/systemd runs `certbot renew` daily; safeguard acts as failsafe.  
- **Config drift:** re-invoking `nginx_proxy` every run ensures template is applied (fixes accidental changes).  
- **Certbot modifications preserved:** `certbot install` doesn't overwrite certbot's comments (important for renewal tracking).

## Troubleshooting

- **Certificate not renewed:** check `/var/log/letsencrypt/renewal-check.log` for safeguard output; check `/var/log/letsencrypt/renew.log` for primary renewal output.  
- **Nginx config broken after certbot:** check `/etc/nginx/sites-available/{{ nginx_site_name }}.backup-*` for backup; role restores if test fails.  
- **Mail alerts not received:** ensure MTA (postfix, sendmail) is installed and configured; safeguard logs to file regardless.
