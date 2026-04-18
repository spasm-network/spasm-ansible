## Spasm forum full server setup

Deploy your [Spasm](https://spasm.network) forum on a new VPS with a single script that handles everything automatically: industry-standard hardening, app installation with Podman, and auto-updates. Enjoy a fully autonomous setup that requires zero server maintenance.

*Note: use [spasm-docker](https://github.com/spasm-network/spasm-docker) repo to launch Spasm on an existing server alongside other apps.*

### Prerequisites

- [DNS points](./docs/DNS.md) to your server IP.
- Ethereum or Nostr address/pubkey for an admin panel.

### System

- OS: Debian 13 (trixie)
- CPU: 1 core
- RAM: 2 GB

### Installation

[SSH](./docs/SSH.md) into your server and execute the following commands from root or admin (sudo).

```bash
# install git (Debian)
sudo apt -y install git

git clone https://github.com/spasm-network/spasm-ansible ~/spasm-ansible/

sudo bash ~/spasm-ansible/server-setup
```

The script asks for your domain name, Ethereum or Nostr address/pubkey, and a server admin password to enable manual interventions (normally, it's not needed since the server is designed to run autonomously).

Your forum will be live after the script finishes execution, which takes about 10 minutes.
