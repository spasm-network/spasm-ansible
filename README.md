## Spasm forum full server setup

Mirrors: [Forgejo](https://git.spasm.network/spasm-network/spasm-ansible) [Codeberg](https://codeberg.org/spasm-network/spasm-ansible) [Github](https://github.com/spasm-network/spasm-ansible)

Deploy your [Spasm](https://spasm.network) forum on a new VPS with a single script that handles everything automatically: industry-standard system hardening, app installation with Podman, and auto-updates. You can also [verify](docs/GPG.md) GPG signatures of all git commits. Enjoy a fully autonomous setup that requires zero server maintenance.

*Note: use [spasm-docker](https://github.com/spasm-network/spasm-docker) repo to launch Spasm on an existing server alongside other apps.*

### Prerequisites

- [DNS points](./docs/DNS.md) to your server IP.
- Ethereum or Nostr address/pubkey for an admin panel.

### System

- OS: Debian 13 (Trixie)
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

The script asks for your domain name (or IP), Ethereum or Nostr address/pubkey, password of a user "admin" (created during the setup) to enable manual interventions (normally, it's not needed since the server is designed to run autonomously).

Your forum will be live after the script finishes execution, which takes about 10 minutes.
