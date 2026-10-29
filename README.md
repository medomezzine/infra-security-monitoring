# Infrastructure Security Monitoring

A small, self-hosted security monitoring stack for two Ubuntu VMs: **Prometheus + Alertmanager + Grafana** in Docker Compose, custom security metrics exposed through the **node-exporter textfile collector**, and alerts delivered to **Telegram**.

## Architecture

```
        VM2 (target)                                 VM1 (monitor)
 ┌──────────────────────────┐              ┌─────────────────────────────────┐
 │ systemd timer (30 s)     │              │ Prometheus ──rules──► Alertmanager │──► Telegram
 │  └ collectors/*.sh       │              │     ▲                     │        │
 │      writes *.prom       │   scrape     │     │                     ▼        │
 │ node-exporter (Docker) ──┼──:9100──────►│     └──── Grafana (dashboards)     │
 └──────────────────────────┘              └─────────────────────────────────┘
 (VM1 also runs node-exporter + collectors, so both VMs are monitored)
```

## Custom security metrics

| Metric | Source | Meaning |
|---|---|---|
| `security_ssh_failed_logins_5m` | journald (`Failed password`) | Failed SSH password attempts in the last 5 min |
| `security_firewall_blocks_5m` | kernel log (`UFW BLOCK` / `FW-BLOCK`) | Packets blocked in the last 5 min |
| `security_process_anomalies{reason}` | `/proc` | Processes executing from `/tmp`, `/var/tmp`, `/dev/shm`, or matching a denylist |
| `security_tls_cert_expiry_seconds{target}` | `openssl s_client` | Seconds until a certificate expires |
| `security_collector_last_success_timestamp_seconds` | all collectors | Freshness of each collector |

## Alert rules (`monitor/prometheus/rules/security.rules.yml`)

| Alert | Condition | For | Severity |
|---|---|---|---|
| `SSHBruteForceDetected` | `security_ssh_failed_logins_5m > 10` | 1m | critical |
| `FirewallBlockSpike` | `security_firewall_blocks_5m > 50` | 2m | warning |
| `SuspiciousProcessDetected` | `sum by (instance) (security_process_anomalies) > 0` | 1m | critical |

A `TLSCertExpiringSoon` rule is included commented-out in the rules file. Rules are unit-tested in `monitor/prometheus/tests/`.

## Repository layout

```
monitor/   Prometheus, Alertmanager, Grafana (docker-compose.yml)      -> VM1
target/    node-exporter compose + collectors + systemd timer          -> both VMs
scripts/   install-docker, render-alertmanager, simulate-bruteforce, validate
docs/      TROUBLESHOOTING.md (Docker-via-snap pitfalls)
```

## Setup

### 0. Docker (both VMs)
Use Docker Engine from Docker's apt repo, **not snap** (see [troubleshooting](docs/TROUBLESHOOTING.md)):
```bash
sudo scripts/install-docker.sh
```

### 1. Collectors + node-exporter (both VMs)
```bash
sudo target/install-collectors.sh          # collectors + systemd timer
cd target && docker compose up -d          # node-exporter on :9100
curl -s localhost:9100/metrics | grep '^security_'
```
Allow the monitor VM to scrape (run on each VM; replace the IP with VM1's):
```bash
sudo ufw allow from 192.168.56.10 to any port 9100 proto tcp
sudo ufw logging medium        # produces the [UFW BLOCK] lines the firewall collector counts
```

### 2. Telegram
1. Create a bot with `@BotFather` and copy the token.
2. Send any message to your bot, then open `https://api.telegram.org/bot<TOKEN>/getUpdates` and read `message.chat.id`.
3. On VM1:
```bash
cd monitor
cp .env.example .env                       # set GRAFANA_ADMIN_PASSWORD and TELEGRAM_CHAT_ID
printf '%s' '<TOKEN>' > secrets/telegram_bot_token
../scripts/render-alertmanager.sh          # generates alertmanager/alertmanager.yml (needs gettext-base for envsubst)
```

### 3. Monitor stack (VM1)
Edit `monitor/prometheus/targets/nodes.yml` with your VM IPs, then:
```bash
cd monitor && docker compose up -d
```
Grafana: `http://<vm1>:3000` (dashboard *Security Overview*). Prometheus and Alertmanager listen on `127.0.0.1` only; use an SSH tunnel (`ssh -L 9090:localhost:9090 vm1`).

### 4. Validate
```bash
scripts/validate.sh        # promtool check config/rules, run rule unit tests, amtool check-config
```

## End-to-end test with a brute-force simulation

Make a throwaway user on VM2 (`sudo adduser --disabled-password labuser`), then from VM1 (or any lab machine):
```bash
sudo apt install hydra
scripts/simulate-bruteforce.sh <vm2-ip>
```
Expected: `security_ssh_failed_logins_5m` climbs above 10, `SSHBruteForceDetected` goes pending then firing (~1-2 min), and a Telegram message arrives. It resolves about 5 minutes after the attempts stop. Only test machines you own.

## Security notes
- Secrets (`.env`, bot token, generated Alertmanager config) are git-ignored; never commit them.
- Collectors run as root (they read the journal and `/proc`); they only write `.prom` files.
- Restrict port 9100 to the monitor VM.
