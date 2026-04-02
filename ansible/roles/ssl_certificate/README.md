# SSL Certificate Role

Automates Let's Encrypt certificate provisioning using certbot --nginx (installer) and manages nginx configuration and renewal.

## Key fixes and behavior
- Runs nginx -t and creates a backup of the nginx site config before running certbot, so the role can restore the previous config if certbot's edits break nginx.
- Uses `certbot --nginx` (installer) so certbot will update nginx vhosts and can add redirects with `--redirect`.
- Handles domain inputs flexibly:
  - `ssl_domain` should be a primary domain (example.com) or a full hostname (app.example.com).
  - `ssl_subdomains` accepts either bare labels (www, api) or full hostnames; bare labels will be expanded to label + primary domain.
- Performs a target-side expiry read (using openssl on the host) and writes JSON from the target, avoiding controller-only lookups.
- Detects certbot binary path and uses it for cron job command.
- Creates /var/log/letsencrypt with secure permissions before writing logs.
- Fails fast on obvious certbot fatal errors (rate limits, auth errors) rather than retrying blindly; retries for transient errors only.
- Idempotent: skips issuance when existing cert has >30 days remaining.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ssl_domain` | `{{ domain }}` | Primary domain or full hostname |
| `ssl_subdomains` | `[]` | List of subdomains or hostnames; supports both bare labels and full domains |
| `ssl_enable_http_to_https_redirect` | `true` | Enable HTTP→HTTPS redirect via certbot (`--redirect`) |
| `ssl_renewal_hour` | `3` | Hour for daily renewal cron job (if no systemd timer) |
| `ssl_cert_path` | `/etc/letsencrypt/live/{{ ssl_domain }}` | Certificate live path |
| `ssl_nginx_conf` | `/etc/nginx/sites-available/{{ nginx_site_name }}` | Path to nginx site file to back up |
| `certbot_webroot` | `/var/www/html` | Webroot directory for ACME challenges (not used by --nginx but kept for compatibility) |
| `ssl_cert_name` | `""` | Optional explicit cert name passed to certbot; defaults to ssl_domain if empty |

## Usage
Include the role after nginx_proxy in your playbook:
```yaml
- hosts: all
  roles:
    - nginx_proxy
    - ssl_certificate
