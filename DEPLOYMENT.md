# Deployment Guide for elektro-luka.com

This document outlines the steps required to deploy the website from scratch on a new Hetzner server (or if the setup breaks and needs to be recreated).

## 1. DNS Configuration (Crucial First Step)

Before doing anything on the server, ensure your domain's DNS records are pointing to the server's public IPv4 address. Let's Encrypt requires these to be active and propagated to issue certificates.

*   **Type:** `A` | **Name:** `@` (or `elektro-luka.com`) | **Value:** `<YOUR_SERVER_IP>`
*   **Type:** `A` | **Name:** `www` | **Value:** `<YOUR_SERVER_IP>`

> **Note on IPv6:** If you are not using IPv6, ensure there are **no `AAAA` records** for `@` or `www`. If Let's Encrypt sees an AAAA record, it will prefer it over IPv4 and the certificate generation will fail if the server/container isn't configured to handle IPv6 traffic correctly.

## 2. Server Preparation

SSH into your server and prepare the necessary directories and permissions. The Podman containers need specific directories to exist on the host system to mount their volumes.

```bash
# SSH into your server
ssh user@<YOUR_SERVER_IP>

# Create the required directories
sudo mkdir -p /var/www/elektro-luka
sudo mkdir -p /var/www/certbot

# Set the correct permissions to your regular user
sudo chown -R $USER:$USER /var/www/elektro-luka
sudo chown -R $USER:$USER /var/www/certbot

# CRITICAL for rootless Podman:
# 1. Allow containers to keep running after you close your SSH connection
loginctl enable-linger $USER
# 2. Ensure containers automatically start if the server reboots
systemctl --user enable podman-restart.service
```

*Ensure that `podman` and `podman-compose` are installed on the server.*

## 3. Transfer Files to Server

From your **local machine**, run the transfer script. This script uses `rsync` to sync your local project files to the `/var/www/elektro-luka` directory on the server.

*   Ensure your `~/.ssh/config` has an entry for `elektro-luka` that points to your server, or modify `transfer_to_server.sh` to use `user@ip`.

```bash
# Run this locally from the project root
./transfer_to_server.sh
```

## 4. Initialize Let's Encrypt and Nginx

Back on the **server**, navigate to the project directory and run the initialization script.

This script does the heavy lifting:
1. Temporarily starts Nginx on port 80 (HTTP only) using `nginx-initial.conf`.
2. Uses Certbot to request the Let's Encrypt certificates (saving them to a Podman volume).
3. Stops the temporary Nginx container.
4. Restarts Nginx with the final `compose.yaml` and `elektro-luka-nginx.conf` (enabling port 443 HTTPS).

```bash
cd /var/www/elektro-luka
sudo ./certbot.sh init
```

If this succeeds, your site is live and secured with HTTPS!

## 5. Automatic Certificate Renewal

Let's Encrypt certificates expire every 90 days. The `certbot.sh` script includes a `renew` command that checks if the certificate is near expiry and renews it if necessary.

To automate this, add a cron job on the server:

```bash
sudo crontab -e
```

Add the following line to run the renewal check twice a day (e.g., at 2:00 AM and 2:00 PM):

```cron
0 2,14 * * * cd /var/www/elektro-luka && sudo ./certbot.sh renew >> /var/log/certbot-renew.log 2>&1
```

## Troubleshooting

*   **If `certbot.sh init` fails with a 500 error:** Let's Encrypt is likely trying to use IPv6 but failing. Double-check that your DNS provider has NO `AAAA` records for the domains.
*   **If `certbot.sh init` fails with NXDOMAIN:** Your DNS `A` records haven't propagated yet, or you forgot to add the record for `www`.
*   **To view container logs:** `podman logs elektro-luka`
