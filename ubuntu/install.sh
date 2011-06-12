#!/bin/bash -e

BACKUP_DIR=/var/araneus
CONFIG=/etc/araneus.conf

function usage {
  echo "Usage: $0 [-n] [-c <config>] [-h]"
  echo "  -n: Dry run (dont change files)"
  echo "  -c: Config file (default $CONFIG)"
  echo "  -h: Display this message"
  exit 1
}

while getopts "hnc:" OPTION; do
  case $OPTION in
  h)
    usage
    ;;
  n)
    echo Dry test mode
    DRY=echo
    ;;
  c)
    CONFIG="${OPTARG}"
    ;;
  ?)
    usage
    ;;
  esac
done

if [ ! -e ${CONFIG} ]; then
  echo "File not found: ${CONFIG}"
  usage
fi

. "${CONFIG}"

if [ -z "${EXTERNAL_IF}" ]; then
  echo EXTERNAL_IF not defined.
  usage
fi

VPN_EXTERNAL_IP=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
if [ -z "${VPN_EXTERNAL_IP}" ]; then
  echo Unable to determine IP address for ${EXTERNAL_IF}
  usage
fi

${DRY} mkdir -p ${BACKUP_DIR}

if [ `id -u` -gt 0 ]; then
  echo Must run as root
  usage
fi

# First install required packages
echo ==== Installing packages
${DRY} apt-get -y install openswan ppp xl2tpd iptables-persistent

# Set appropriate sysctl

function install_conf {
  f="$(basename $1)"
  echo "==== Installing $f -> $1"
  if [ -e "$1" ]; then
    echo "     (backing up existing file to ${BACKUP_DIR})"
    ${DRY} cp "$1" "${BACKUP_DIR}/${f}"
  fi
  ${DRY} cp "${f}.in" "$1"
}

function subst {
  if [ -z "$3" ]; then 
    echo Error: undefined variable $2 for $1
    exit 1
  fi
  ${DRY} sed -e "s,@$2@,$3,g" -i $1
}

install_conf /etc/ipsec.conf
subst /etc/ipsec.conf "VPN_NETWORK" "${VPN_NETWORK}"

install_conf /etc/ipsec.d/l2tp-psk.conf
subst /etc/ipsec.d/l2tp-psk.conf "VPN_EXTERNAL_IP" "${VPN_EXTERNAL_IP}"

install_conf /etc/xl2tpd/xl2tpd.conf
subst /etc/xl2tpd/xl2tpd.conf "VPN_NETWORK_START_IP" "${VPN_NETWORK_START_IP}"
subst /etc/xl2tpd/xl2tpd.conf "VPN_NETWORK_END_IP" "${VPN_NETWORK_END_IP}"
subst /etc/xl2tpd/xl2tpd.conf "VPN_NETWORK_LOCAL_IP" "${VPN_NETWORK_LOCAL_IP}"

install_conf /etc/ppp/options.xl2tpd
subst /etc/ppp/options.xl2tpd "VPN_DNS_IP" "${VPN_DNS_IP}"

install_conf /etc/ipsec.secrets
subst /etc/ipsec.secrets "VPN_EXTERNAL_IP" "${VPN_EXTERNAL_IP}"
subst /etc/ipsec.secrets "PSK_SECRET" "${PSK_SECRET}"
${DRY} chmod 600 /etc/ipsec.secrets

# never overwrite chap-secrets
if [ ! -e /etc/ppp/chap-secrets ]; then
  install_conf /etc/ppp/chap-secrets
  subst /etc/ppp/chap-secrets "VPN_NETWORK_START_IP" "${VPN_NETWORK_START_IP}"
  ${DRY} chmod 600 /etc/ppp/chap-secrets
fi

install_conf /etc/sysctl.d/60-vpn.conf

${DRY} mkdir -p /etc/iptables
install_conf /etc/iptables/rules
subst /etc/iptables/rules "EXTERNAL_IF" "${EXTERNAL_IF}"

${DRY} /etc/init.d/iptables-persistent restart
${DRY} /etc/init.d/ipsec restart
${DRY} /etc/init.d/xl2tpd restart

# bug: https://bugs.launchpad.net/ubuntu/+source/openswan/+bug/554592
${DRY} update-rc.d -f ipsec remove
${DRY} update-rc.d ipsec defaults
