#!/usr/bin/env bash 

loc_port=80

screen -dmS iperf_tcp sudo iperf -s -p $loc_port
screen -dmS iperf_udp sudo iperf -s -u -p $loc_port
screen -dmS pttcp echo need to see how I run this
ssh -i ~/.ssh/id_rsa -L 5001:localhost:5001 -L  6000:localhost:6000   -L  6001:localhost:6001  -L  6002:localhost:6002  -L  6003:localhost:6003  -L  6004:localhost:6004 cr409@chicane

 ssh -i ~/.ssh/id_rsa -L 6001:localhost:5001 -R localhost:6002:localhost:6002  -L  8000:localhost:7000   -L  8001:localhost:7001  -L  8002:localhost:7002  -L  8003:localhost:7003  -L  8004:localhost:7004  -L  8005:localhost:7005  -L  8006:localhost:7006  -L  8007:localhost:7007  -L  8008:localhost:7008  -L  8009:localhost:7009  -L  8010:localhost:7010 cr409@ns.i.d12.signpp.st

tcpdump -i any -C 500 -w /data/server_capture/mon
