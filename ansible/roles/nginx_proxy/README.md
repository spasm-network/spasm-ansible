## Purpose
- Host nginx reverse-proxy that forwards traffic to a local container proxy (default 127.0.0.1:33333), prepares ACME HTTP-01 webroot, and renders per-site configs idempotently and safely for multi-site deployments.

## Design goals
- Safe defaults for fresh servers (HTTPS disabled until valid certs present).
- Multi-site support without nginx conflicts (no duplicate global map/upstream errors).
- Deterministic TLS rendering (render HTTPS only when cert files verified).
- Idempotent, test-before-reload workflow to avoid service disruption.

## Quick concept
- Shared nginx items used by all sites (map for websocket handling) are deployed once to /etc/nginx/conf.d/proxy_common.conf.
- Each site gets a per-site config under /etc/nginx/sites-available/<nginx_site_name> and a symlink into sites-enabled.
- Each site defines its own upstream named <nginx_site_name>_backend pointing at nginx_upstream_host:nginx_backend_port to avoid upstream name collisions.
- Templates are safe to re-run; nginx config is tested (nginx -t) and only reloaded on success. On failures, the handler logs the failing site config for debugging and fails the playbook with test output.

## Key variables (most important)
- nginx_site_name: filename and logical site identifier (default app-proxy)
- nginx_upstream_host: host for upstream server (default 127.0.0.1)
- nginx_upstream_name: unique upstream name (default "{{ nginx_site_name }}_backend")
- nginx_backend_port: upstream port (default 33333)
- nginx_client_max_body_size: upload size (default 50M)
- certbot_webroot: ACME webroot (default /var/www/certbot)
- nginx_ssl_enabled: role flag (false by default; set by ssl_certificate role)
- ssl_cert_path / ssl_key_path: paths set by ssl_certificate role after obtaining certs
- certs_present (internal fact): true only when nginx_ssl_enabled is true AND ssl_cert_path is set AND the cert file exists — used to deterministically render HTTPS blocks and redirects
- http_redirect_to_https: if true and certs_present true, HTTP returns 301 → HTTPS

## Behavior summary
- Creation:
  - Ensures nginx package installed and service enabled.
  - Creates /etc/nginx/sites-available, /etc/nginx/sites-enabled, /etc/nginx/conf.d, and the ACME webroot (certbot_webroot).
  - Deploys /etc/nginx/conf.d/proxy_common.conf (map for websockets).
  - Renders per-site /etc/nginx/sites-available/{{ nginx_site_name }} from proxy.conf.j2.
  - Ensures symlink exists in /etc/nginx/sites-enabled and optionally removes default site.

- TLS handling:
  - The role checks for ssl_cert_path existence and sets certs_present accordingly.
  - HTTPS server block and HTTP→HTTPS redirect are rendered only when certs_present is true.
  - If http_redirect_to_https is requested but certs are missing, the role fails with a clear message (avoids silent fallback).
  - Recommended flow: run ssl_certificate role to obtain certs and set ssl_cert_path/ssl_key_path, then re-run nginx_proxy.

- Multi-site safety:
  - Shared map placed in one conf.d file to avoid duplicate declarations.
  - Upstream names are per-site to avoid collisions when multiple sites are enabled.
  - Users may override nginx_upstream_name intentionally to share an upstream.

- WebSocket support:
  - Global map ($http_upgrade → $connection_upgrade) in proxy_common.conf used by all site configs so Connection header can be set safely per-request.

- Config testing and reload:
  - Handled atomically in a handler that runs nginx -t and reloads nginx on success.
  - On failure the handler saves the site template file to /var/log/nginx/failed-<site>-<timestamp>.conf and fails the play with nginx -t output.

## Operational notes and recommendations
- Ensure ssl_certificate role sets ssl_cert_path and ssl_key_path before invoking or re-running nginx_proxy to enable HTTPS smoothly.
- If you want a single global upstream or global proxy behavior, explicitly set nginx_upstream_name to a shared value across sites (intentional override).
- On SELinux systems, ensure ssl_certificate role or a separate task sets the correct SELinux file contexts on cert files and the certbot_webroot after creation.
- Consider improving the failure handler to capture nginx -T output for a full assembled config when debugging complex include-related failures.
- Be cautious with http_redirect_to_https: it will fail the play if certs are absent to avoid accidental misconfiguration.

## Files of interest
- tasks/main.yml — orchestration, cert existence check, certs_present fact, template deploys.
- templates/proxy_common.conf.j2 — shared map definitions.
- templates/proxy.conf.j2 — per-site config (per-site upstream + HTTP/HTTPS server blocks).
- handlers/main.yml — nginx -t + atomic reload logic.

## Example usage (single domain)
- Set DOMAIN_NAME in playbook or pass as var; role will normalize to domain_list.
- Run ssl_certificate role to obtain certs (sets nginx_ssl_enabled true and ssl_cert paths), then re-run nginx_proxy to render HTTPS block and optionally enable redirect.
