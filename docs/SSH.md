## SSH guide

##### Add your SSH .pub to your VPS provider

Upload the SSH key generated above into the SSH form while setting up
your server, so you can log into the server without a password.

On Linux SSH .pub is usually located at `~/.ssh/YOUR_NAME.pub`

Manually copy the content of `YOUR_NAME.pub` to clipboard
using a text editor, e.g.:

```shell
nano ~/.ssh/user.pub
```

Or from the terminal, e.g.:

```shell
cat ~/.ssh/user.pub
```

Or with a `wl-copy` command if wl-clipboard is installed, e.g.:

```shell
wl-copy < ~/.ssh/user.pub
```

Open your VPS provider and paste your SSH pub key into an SSH form.

*Note: it's important to use SSH keys because the password authentication
will be disabled by one of the following setup scripts.*

##### Testing in VM

If you're testing the app locally in a virtual machine (VM),
then paste your SSH key into `/root/.ssh/authorized_keys`

##### SSH into your server

Once your server is built by the VPS provider, you can try to log into it.

```shell
# SSH into your server as root
ssh -i ~/.ssh/YOUR_SSH_KEY root@YOUR_SERVER_IP_ADDRESS
# Example:
ssh -i ~/.ssh/user root@20.21.03.01
```

You should get the following message, type `yes` and press enter
to add the server key fingerprint to your known hosts.

```
The authenticity of host 'YOUR_SERVER_IP_ADDRESS' can't be established.
ED25519 key fingerprint is SHA256:YOUR_SERVER_FINGERPRINT.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

Sometimes your connection might be closed:

```
Warning: Permanently added 'YOUR_SERVER_IP_ADDRESS' (ED25519) to the list of known hosts.
Connection closed by YOUR_SERVER_IP_ADDRESS port 22
```

Simply try to log in again with the same command.

```shell
# Example:
ssh -i ~/.ssh/user root@20.21.03.01
```

*Note: try to log in again if you got error 'Broken pipe'.*

If you got another error, then read the troubleshooting section below.

#### SSH Troubleshooting

**Clean known hosts after rebuild**

*Note: skip this step if you've never logged into your server before.*

Sometimes you can mess up the setup process, so it might be easier
to rebuild your server and start the setup process from the scratch.
However, you'll get an error when trying to SSH into a server that
has been recently rebuilt.

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ED25519 key sent by the remote host is
SHA256:YOUR_SERVER_FINGERPRINT.
Please contact your system administrator.
```

In that case, don't forget to clean the `~/.ssh/known_hosts` file
from old key fingerprints before trying to SSH into your server
because your server key fingerprint has changed after rebuild.

```shell
# '-R' deletes a pub key of your previous server build.
ssh-keygen -R YOUR_SERVER_IP_ADDRESS
# Example:
ssh-keygen -R 20.21.03.01
```

Then try to SSH into your server without `sudo`:

```shell
# SSH into your server as root
ssh -i ~/.ssh/YOUR_SSH_KEY root@YOUR_SERVER_IP_ADDRESS
# Example:
ssh -i ~/.ssh/user root@20.21.03.01
```

You should get the following message, type `yes` and press enter
to add the server key fingerprint to your known hosts.

```
The authenticity of host 'YOUR_SERVER_IP_ADDRESS' can't be established.
ED25519 key fingerprint is SHA256:YOUR_SERVER_FINGERPRINT.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```
