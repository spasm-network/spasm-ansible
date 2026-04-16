Role: app_deployment

Purpose:
- Validate required variables (app_repo_url, app_clone_path)
- Clone an application repository into the target user's home
- If repo exists: fetch origin and hard-reset local changes (will discard local modifications)
- Create .env file on first run with optional vars (ADMINS, POSTGRES_PASSWORD, HOST_PORT)
  - Only creates if at least one var is defined and non-empty
  - Never modifies existing .env (idempotent, safe to re-run)
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
- .env is created only on first run; existing .env files are never modified.
