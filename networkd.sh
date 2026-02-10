#!/usr/bin/env bash
set -euo pipefail
trap ':' ERR


SECTION() {
  echo
  echo "==============================================================================="
  echo "== $1"
  echo "==============================================================================="
}

CMD() {
  echo
  echo "+ $*"
  "$@" || true
}

SECTION "Basic system info"
CMD uname -a
CMD systemd --version

SECTION "systemd-networkd service status"
CMD systemctl status systemd-networkd --no-pager
CMD systemctl cat systemd-networkd --no-pager

SECTION "Merged systemd-networkd.conf (AUTHORITATIVE)"
CMD systemd-analyze cat-config systemd/networkd.conf

SECTION "Explicit ManageForeign* settings (admin intent)"
# CMD grep -R --line-number --ignore-case ManageForeign /etc/systemd/networkd.conf /etc/systemd/networkd.conf.d 2>/dev/null || true

SECTION "systemd-networkd configuration files (priority order)"

echo
echo "-- /etc/systemd/network (admin overrides)"
CMD ls -l /etc/systemd/network || true

echo
echo "-- /run/systemd/network (runtime / generated, e.g. netplan)"
CMD ls -l /run/systemd/network || true

echo
echo "-- /usr/lib/systemd/network (vendor defaults)"
CMD ls -l /usr/lib/systemd/network || true

SECTION "systemd-networkd config deltas"
CMD systemd-delta --type=network

SECTION "Per-interface networkd view"
CMD networkctl list
CMD networkctl status

SECTION "Kernel network state"
CMD ip addr
CMD ip route

echo
echo "+ ip rule (best-effort)"
ip rule show || true

SECTION "Netplan (if present)"
if [ -d /etc/netplan ]; then
  CMD ls -l /etc/netplan
  CMD netplan get
else
  echo "Netplan not present"
fi

SECTION "Competing network managers"
CMD systemctl is-enabled NetworkManager
CMD systemctl is-enabled systemd-networkd
CMD systemctl is-enabled ifupdown 2>/dev/null || true

SECTION "Recent systemd-networkd logs"
CMD journalctl -u systemd-networkd --no-pager -n 200

echo
echo "Diagnostics collection complete."
