mkdir -p /etc/iptables && iptables-save > /etc/iptables/rules.v4

cat>/etc/systemd/system/tproxyrule.service<<-EOF
[Unit]
Description=Tproxy rule
After=network.target
Wants=network.target

[Service]

Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/ip rule add fwmark 1 table 100 ; /sbin/ip route add local 0.0.0.0/0 dev lo table 100 ; /sbin/iptables-restore /etc/iptables/rules.v4
ExecStop=/sbin/ip rule del fwmark 1 table 100 ; /sbin/ip route del local 0.0.0.0/0 dev lo table 100 ; /sbin/iptables -t mangle -F

[Install]
WantedBy=multi-user.target

EOF

systemctl enable tproxyrule
