# GliderProxy Testing Skill

## Purpose

Use this skill when testing GliderProxy manager (`glider.sh`) changes, especially install, user management, systemd, iptables, and traffic statistics flows.

## Devin Secrets Needed

- None for local VM testing. The tested flow uses only local root permissions, systemd, iptables, `curl`, and `expect`.

## Required Local Tools

Install these before E2E testing if missing:

```bash
sudo apt-get update
sudo apt-get install -y expect curl iptables shellcheck
```

## Static Checks

From the repo root:

```bash
bash -n glider.sh
shellcheck glider.sh
git diff --check
```

## Runtime Test Setup

The manager writes root-owned files and firewall state. Use `sudo` for setup, assertions, and cleanup.

Important paths:

- Manager script: `/usr/local/bin/glider-manager`
- Config: `/etc/glider/glider.conf`
- Service: `/etc/systemd/system/glider.service`
- Stats dir: `/var/lib/glider-manager/stats`
- Stats state: `/var/lib/glider-manager/stats/traffic.tsv`
- Deleted-user archive: `/var/lib/glider-manager/stats/deleted.tsv`
- Stats chains: `GLIDER_STATS_IN`, `GLIDER_STATS_OUT`

Clean state before a destructive local E2E run:

```bash
sudo systemctl stop glider 2>/dev/null || true
sudo systemctl disable glider 2>/dev/null || true
sudo rm -rf /etc/glider /var/lib/glider-manager
sudo rm -f /usr/local/bin/glider-bin /etc/systemd/system/glider.service
sudo systemctl daemon-reload >/dev/null 2>&1 || true
sudo iptables -D INPUT -j GLIDER_STATS_IN >/dev/null 2>&1 || true
sudo iptables -D OUTPUT -j GLIDER_STATS_OUT >/dev/null 2>&1 || true
sudo iptables -F GLIDER_STATS_IN >/dev/null 2>&1 || true
sudo iptables -F GLIDER_STATS_OUT >/dev/null 2>&1 || true
sudo iptables -X GLIDER_STATS_IN >/dev/null 2>&1 || true
sudo iptables -X GLIDER_STATS_OUT >/dev/null 2>&1 || true
sudo install -m 755 glider.sh /usr/local/bin/glider-manager
sudo ln -sf /usr/local/bin/glider-manager /usr/local/bin/glider
```

## E2E Flow for User Traffic Statistics

Use the real `sudo /usr/local/bin/glider-manager` TUI, preferably driven by `expect`, to keep evidence close to user behavior.

Recommended adversarial flow:

1. Install Glider with an unused control user `stats2` on port `18444`.
2. Add the traffic-tested user `stats1` on port `18443`.
3. Generate real HTTP proxy traffic only through `stats1`:

```bash
curl --max-time 20 --proxy http://stats1:pass1@127.0.0.1:18443 http://example.com/ >/dev/null
```

4. Verify `/etc/glider/glider.conf` contains both users and the systemd unit contains:

```text
ExecStartPre=-/usr/local/bin/glider-manager --sync-stats
```

5. Verify stats rules exist:

```bash
sudo iptables -L GLIDER_STATS_IN -v -x -n
sudo iptables -L GLIDER_STATS_OUT -v -x -n
```

Expected rule markers include `tcp dpt:18443`, `udp dpt:18443`, `tcp spt:18443`, `udp spt:18443`, plus the control port `18444`.

6. Open `Статистика` and verify `stats1` total is greater than `0 B` while `stats2` remains `0 B`.
7. Reset `stats1` and verify port `18443` returns to `0` in `/var/lib/glider-manager/stats/traffic.tsv`.
8. Generate more traffic for `stats1`, change its port from `18443` to `18445`, and verify old rules are removed and new `18445` rules exist.
9. Generate traffic on `18445`, delete `stats1`, and verify `/var/lib/glider-manager/stats/deleted.tsv` contains `stats1`, `18445`, and non-zero total bytes.
10. Uninstall via `Удалить Glider` and verify `/etc/glider`, `/var/lib/glider-manager/stats`, `/usr/local/bin/glider-bin`, `/etc/systemd/system/glider.service`, and both stats chains are absent.

## Expect Harness Tips

- New users are inserted above older users in `glider.conf`, so create the unused control user first and add the target user second. This makes the target user the first picker row for reset/edit/delete.
- Avoid relying on arrow navigation inside nested user pickers when stale table output is still in the terminal buffer. Prefer constructing the data so the target row is first, then press Enter after matching the displayed login/port.
- After evidence-only screens such as `Архив статистики`, close the spawned expect PTY after matching the expected row; do not send extra buffered arrows through nested menus.
- After uninstall success (`Glider полностью удалён`), close the spawned expect PTY before post-cleanup assertions; do not navigate the post-uninstall menu.
- The cleanup assertion should target `/var/lib/glider-manager/stats`, not necessarily the parent `/var/lib/glider-manager`, because the uninstall code removes `$STATS_DIR`.

## Evidence to Capture

For shell-only CLI testing, no screen recording is needed. Attach:

- Full `expect`/shell log
- Summary of pass/fail assertions
- Screenshots or rendered images of key log excerpts showing traffic separation, archive row, and cleanup results
