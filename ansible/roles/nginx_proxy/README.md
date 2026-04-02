Purpose:
- Configure host nginx to proxy traffic to a local Docker/Podman mapped port (default 33333).
- Prepare ACME HTTP-01 challenge location and security headers so ssl_certificate role can operate without further structural changes.
- Upstream block added for future extensibility.
- Idempotent, tests nginx config before reload, saves failing configs for debugging.

Usage:
- Call this role before roles/ssl_certificate in playbook so port 80 is ready for ACME validation.
- Toggle features via role vars (see vars/main.yml).
