apt update && apt install -y rust-1.89 git
cd /opt

git clone https://github.com/telemt/telemt.git
cd telemt
cargo-1.89 build --release
chmod +x ./target/release/telemt
ln -s /opt/telemt/target/release/telemt /usr/bin/telemt

KEY=$(openssl rand -hex 16)
TLS_DOMAIN=files.strelok.spb.ru

cat << EOT > /etc/telemt.toml
# === UI ===
# Users to show in the startup log (tg:// links)
show_link = ["hello"]

# === General Settings ===
[general]
prefer_ipv6 = false
fast_mode = true
use_middle_proxy = false
#ad_tag = "..." # Replace zeros to your adtag from @mtproxybot

[general.modes]
classic = false
secure = false
tls = true

# === Server Binding ===
[server]
port = 443
listen_addr_ipv4 = "0.0.0.0"
listen_addr_ipv6 = "::"
# metrics_port = 9090
# metrics_whitelist = ["127.0.0.1", "::1"]

# Listen on multiple interfaces/IPs (overrides listen_addr_*)
[[server.listeners]]
ip = "0.0.0.0"
# announce_ip = "1.2.3.4" # Optional: Public IP for tg:// links

[[server.listeners]]
ip = "::"

# === Timeouts (in seconds) ===
[timeouts]
client_handshake = 15
tg_connect = 10
client_keepalive = 60
client_ack = 300

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "${TLS_DOMAIN}"
mask = true
mask_port = 443
# mask_host = "${TLS_DOMAIN}" # Defaults to tls_domain if not set
fake_cert_len = 2048

# === Access Control & Users ===
# username "hello" is used for example
[access]
replay_check_len = 65536
ignore_time_skew = false

[access.users]
# format: "username" = "32_hex_chars_secret"
hello = "$KEY"

# [access.user_max_tcp_conns]
# hello = 50

# [access.user_data_quota]
# hello = 1073741824 # 1 GB

# === Upstreams & Routing ===
# By default, direct connection is used, but you can add SOCKS proxy

# Direct - Default
[[upstreams]]
type = "direct"
enabled = true
weight = 10

# SOCKS5
# [[upstreams]]
# type = "socks5"            # Specify SOCKS4 or SOCKS5
# address = "1.2.3.4:1234"   # SOCKS-server Address
# username = "user"          # Username for Auth on SOCKS-server
# password = "pass"          # Password for Auth on SOCKS-server
# weight = 1                 # Set Weight for Scenarios
# enabled = true

EOT

cat << EOT > /etc/systemd/system/telemt.service
[Unit]
Description=Telemt
After=network.target

[Service]
Type=simple
WorkingDirectory=/bin
ExecStart=/bin/telemt /etc/telemt.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable telemt
systemctl start telemt

journalctl -n 100 | grep telemt