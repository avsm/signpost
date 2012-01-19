This folder contains all monitoring scripts that are used to benchmark the tunninelling tecnologies.

tcp_perf.pl -> parses the iperf and ping output files and outputs the median, min, max aand avg throughput and latency respctively. 
./tcp_perf.pl -i input_dir -o output_dir -m [iperf|ping] -l [lab|aws]


