#!/bin/sh -e

BACKUP_DIR=/var/backup/araneus

mkdir -p ${BACKUP_DIR}

if [ `id -u` -gt 0 ]; then
  echo Must run as root
fi

# First install required packages
echo ==== Installing packages
apt-get -y install openswan ppp xl2tpd

# Set appropriate sysctl

function install_conf {
  f="$(basename $1)"
  echo "==== Installing $f -> $1"
  if [ -e "$1" ]; then
    echo "     (backing up existing file to ${BACKUP_DIR})"
    cp "$1" "${BACKUP_DIR}/$1"
  fi
  cp "${f}.in" "$1"
}

install_conf /etc/ipsec.conf
install_conf /etc/ipsec.d/l2tp-psk.conf
install_conf /etc/xl2tpd/xl2tpd.conf
install_conf /etc/ppp/options.xl2tpd
install_conf /etc/ipsec.secrets
install_conf /etc/ppp/chap-secrets
install_conf /etc/sysctl.d/60-vpn.conf
