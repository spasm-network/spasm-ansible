Role: app_deployment

Purpose:
- Validate required variables (app_repo_url, app_clone_path)
- Clone an application repository into the target user's home
- If repo exists: fetch origin and hard-reset local changes (will discard local modifications)
- Write an idempotent .env for the app by adding missing keys only (does NOT overwrite existing values)
- Detect available container runtime (podman/docker) with compose support
- Validate and run compose (podman/docker compose)
- Perform a basic smoke test to ensure the app listens on configured port
- Produce a run_summary JSON for control machine logging

Notes:
- Role is idempotent and safe to re-run.
- Owner/group variables should be provided by caller.
- app_repo_url and app_clone_path must be defined.
- host_port must be > 0 for smoke test to run.
- logs_dir defaults to playbook_dir/logs; if playbook_dir is undefined, set logs_dir explicitly in play vars.
- Requires podman 5.4+ or docker.
- The clone step will reset local changes; ensure important local changes are backed up before running.
- .env updates only add missing keys (ADMINS, POSTGRES_PASSWORD, HOST_PORT); existing values are preserved.
