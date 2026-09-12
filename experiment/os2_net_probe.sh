#!/bin/bash
cd "$(dirname "$0")/.." || exit 1
{
  echo "== resolv =="; cat /etc/resolv.conf | grep -v '^#'
  echo "== ahosts archive.ubuntu.com =="; getent ahosts archive.ubuntu.com | head -6
  echo "== curl -4 http archive =="; curl -4 -sS -m 15 -o /dev/null -w "%{http_code} %{remote_ip}\n" http://archive.ubuntu.com/ubuntu/ ; echo "rc $?"
  echo "== curl -4 https archive =="; curl -4 -sS -m 15 -o /dev/null -w "%{http_code} %{remote_ip}\n" https://archive.ubuntu.com/ubuntu/ ; echo "rc $?"
  echo "== curl -4 https cdn.kernel.org =="; curl -4 -sS -m 15 -o /dev/null -w "%{http_code} %{remote_ip} %{speed_download}\n" https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc ; echo "rc $?"
  echo "== ip route =="; ip -4 route | head -3; ip -6 route 2>/dev/null | head -3
  echo "== apt sources =="; cat /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null | grep -E 'URIs|Suites' | head -4
  echo "== dpkg gcc make qemu =="; dpkg -l gcc make qemu-system-x86 flex bison 2>/dev/null | grep '^ii' | awk '{print $2, $3}'
} > zig-out/wsl/net_probe.txt 2>&1
