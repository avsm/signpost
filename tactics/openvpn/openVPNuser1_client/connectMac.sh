if [ -z "$1" ]; then
   echo Error: undefined server IP
   exit 1
fi

function subst {
    if [ -z "$4" ]; then
        echo Error: undefined variable $2 for $1
        exit 1
    fi
    sed "s,@$3@,$4,g" $1 > $2
}

cp openvpn.conf.template openvpn.conf
subst openvpn.conf.template openvpn.conf "VPN_SERVER_IP" $1
openvpn2 --config openvpn.conf 
