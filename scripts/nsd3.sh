#!/usr/bin/env bash
# Generate NSD configuration file for a Signpost running on EC2, with Iodine support

set -e

function usage {
  echo "$0 -n <signpost name> [-h]"
  echo "-n : assign this name in the zone file"
  echo "-h : display this message"
  echo
  echo "Will write output to $NSDCONF"
  exit 1
}

NAME=
ZONE=signpo.st
while getopts "n:" opt; do
  case $opt in
    n)
      NAME="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ -z "$NAME" ]; then
  echo Must specify a Signpost name with -n
  usage 
fi

BUMP=06
NSDCONF="/etc/nsd3/nsd.conf"
ZONECONF="/etc/nsd3/${NAME}.${ZONE}.zone"
IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)

if [ -e "${NSDCONF}" ]; then
  mv ${NSDCONF} ${NSDCONF}.bak
fi

SECRET=$(dd if=/dev/random bs=16 count=1 2>/dev/null | openssl base64)
SERIAL="$(date +%Y%m%d)${BUMP}"
cat > ${NSDCONF} <<ENDNSD
server:
  port: 5353
  verbosity: 2

key:   
  name: "signpost_key"
  algorithm: hmac-md5
  secret: "${SECRET}"

zone:  
  name: "${NAME}.${ZONE}"
  zonefile: "${NAME}.${ZONE}.zone"
ENDNSD

cat > ${ZONECONF} <<ENDZONE
\$TTL 0

@ IN SOA ${IP}. hostmaster.${NAME}.${ZONE}. (
  ${SERIAL}       ; serial number YYMMDDNN
  28800           ; Refresh
  7200            ; Retry
  864000          ; Expire
  86400           ; Min TTL
)

@ A ${IP}
i NS ${HOSTNAME}.
ENDZONE
