# GliderProxy

```bash
sudo bash -c 'wget -q https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh -O /usr/local/bin/glider-manager && chmod +x /usr/local/bin/glider-manager && mv /usr/local/bin/glider /usr/local/bin/glider-bin 2>/dev/null || true && ln -sf /usr/local/bin/glider-manager /usr/local/bin/glider && sed -i "s|ExecStart=/usr/local/bin/glider |ExecStart=/usr/local/bin/glider-bin |g" /etc/systemd/system/glider.service 2>/dev/null || true && systemctl daemon-reload 2>/dev/null && systemctl restart glider 2>/dev/null || true' && sudo glider
```
