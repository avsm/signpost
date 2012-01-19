#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  tcp_perf.pl
#
#        USAGE:  ./tcp_perf.pl 
#
#  DESCRIPTION:  Meausre packet rate 
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:   (), <>
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  17/01/12 00:01:59 GMT
#     REVISION:  ---
#===============================================================================

# use strict;
use warnings;

use Test::More;
use Net::Pcap;

if(@ARGV < 3) {
    print "Not enough arguments\n";
    exit;
}

$input_file = $ARGV[0];
$delay = $ARGV[1];
$output_file = $ARGV[2];

# Find a device and open it
# $dev = find_network_device();
# $pcap = Net::Pcap::open_live($dev, 1024, 1, 0, \$err);

# calling open_offline() with a non-existent file name
$pcap = Net::Pcap::open_offline($input_file, \$err);

my $packet_count = 0;
my $bytes_count = 0;
my $last_sec = 0;
my $last_usec = 0;

my $bin_count = 0;
open (OUT, ">", $output_file);

while(1) {
    $pkt = Net::Pcap::pcap_next($pcap, \%header);
    if (! $pkt ) {
        last;
    }

    if ($last_sec) {

        if ( ( ( $header{"tv_sec"} - $last_sec) * 1000000 + 
                ( $header{"tv_usec"} - $last_usec)  ) > $delay * 1000) {
            print OUT (++$bin)." ". $packet_count . " " . $bytes_count. "\n";
            print "outputing data\n";
            $packet_count = 0;
            $bytes_count = 0;
            $last_sec = $header{"tv_sec"};
            $last_usec = $header{"tv_usec"};

        }
    } else {
        $last_sec = $header{"tv_sec"};
        $last_usec = $header{"tv_usec"};
    }

    $packet_count++;
    $bytes_count +=$header{"len"}; 
#    print $_."\n" foreach (keys header);
#    print "Reading packet ".(++$packet_count)."\n";
}

print OUT (++$bin)." ". $packet_count . " " . $bytes_count. "\n";
close(OUT);
print "Finished processing\n";
