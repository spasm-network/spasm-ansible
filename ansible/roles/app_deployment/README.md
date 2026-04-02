Role: app_deployment

Purpose:
- Validate required variables (app_repo_url, app_clone_path)
- Clone an application repository into the target user's home
- Write an idempotent .env for the app
- Detect available container runtime (podman/docker) with compose support
- Validate and run compose (podman-compose / podman compose / docker compose)
- Perform a basic smoke test to ensure the app listens on configured port
- Produce a run_summary JSON for control machine logging

Notes:
- Role is designed to be idempotent and safe to re-run.
- Owner/group variables should be provided by caller.
- app_repo_url and app_clone_path must be defined.
- host_port must be > 0 for smoke test to run.
- logs_dir defaults to playbook_dir/logs; if playbook_dir is undefined, set logs_dir explicitly in play vars.
- Requires podman 5.4+ or docker. podman-compose (legacy) is no longer supported.
