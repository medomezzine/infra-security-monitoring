# Troubleshooting

Most problems on this project came from running Docker installed via **snap**. The fix for all three below is the same: install Docker Engine from Docker's apt repo (`scripts/install-docker.sh`).

## 1. Mount paths fail or appear empty

**Symptom:** `docker compose up` errors on bind mounts, or a container starts but sees an empty directory (e.g. node-exporter finds no `.prom` files).

**Cause:** snap confinement limits which host paths the daemon can bind-mount (essentially your home directory and snap-owned paths). Mounts such as `/var/lib/node_exporter/textfile_collector` or `/` may be denied or not visible.

**Fix:** use apt Docker (no confinement). A workaround on snap is to keep everything under `$HOME`, but then the textfile path in `target/docker-compose.yml` and the collectors' `TEXTFILE_DIR` must both point there.

## 2. Containers can't reach the network / are unreachable (iptables FORWARD DROP)

**Symptom:** Prometheus can't scrape the other VM, or containers have no outbound access; `iptables -S FORWARD` shows `-P FORWARD DROP`.

**Cause:** Docker sets the FORWARD policy to DROP and manages its own chains. If ufw or custom rules also manage FORWARD (for example `DEFAULT_FORWARD_POLICY="DROP"` in `/etc/default/ufw`), traffic from containers is dropped.

**Fix:** do not flip the whole policy to ACCEPT. Allow what you need:
```bash
sudo ufw route allow in on docker0          # or the compose bridge, e.g. br-xxxx
# or add rules to the DOCKER-USER chain, which Docker evaluates first:
sudo iptables -I DOCKER-USER -i docker0 -j ACCEPT
```
Check with `sudo iptables -S FORWARD` and `sudo iptables -L DOCKER-USER -n -v`. Also note that ports published by Docker bypass ufw's INPUT rules; that is why Prometheus/Alertmanager are published on `127.0.0.1` only.

## 3. `docker stop` / `docker kill` fails with permission denied

**Symptom:** `cannot kill container ... permission denied` / containers can't be stopped or removed.

**Cause:** the snap's AppArmor profile does not permit the daemon to signal container processes.

**Fix:** switch to apt Docker. As a stopgap, `sudo aa-remove-unknown` is commonly suggested, or reboot to clear stuck containers.

## Other checks

| Problem | Check |
|---|---|
| No `security_*` metrics | `ls -l /var/lib/node_exporter/textfile_collector`, `systemctl status security-collectors.timer`, `journalctl -u security-collectors` |
| Target down in Prometheus | `curl http://<vm>:9100/metrics` from VM1; ufw rule for port 9100 |
| No Telegram message | `docker logs alertmanager`; confirm token file and `chat_id`; send a test alert: `docker exec alertmanager amtool alert add test severity=critical --alertmanager.url=http://localhost:9093` |
| Firewall metric always 0 | `sudo ufw logging medium` and confirm `[UFW BLOCK]` lines appear in `journalctl -k` |
| `alertmanager.yml` missing | run `scripts/render-alertmanager.sh` |
