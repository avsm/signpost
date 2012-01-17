if [ -z "$2" ]; then
   echo Error: need to specify both endpoints
   exit 1
fi

function subst {
    if [ -z "$4" ]; then
        echo Error: undefined variable $3 for $2
        exit 1
    fi
    echo $3
    echo $4
    sed "s,@$3@,$4,g" $1 > $2
}

cp setkey.conf /etc/setkey.conf 

subst /etc/setkey.conf temp-setkey.conf "LOCAL" $1
subst temp-setkey.conf /etc/setkey.conf "REMOTE" $2

setkey -f /etc/setkey.conf

./enable_decap
