#!/usr/bin/env perl

use Getopt::Long;
use signpost_transform;

use warnings;
use strict;

print "key convert running\n";

my %conf = ();

my @key_types = ("dns_pub",  # fetch or read a dnskey record
             "dns_priv", # dnssec private key format
             "pem_pub",  # a pem public key
             "pem_priv", # a pem private key
             "pem_cert"); # a pem certificate type

my @action_types = ("sign", "transform", "verify");


sub check_input {
    my $opt = shift ;

    # checking validity for key type
    if ((!exists($opt->{"in_type"} ) ) ||
        (!($opt->{"in_type"} ~~ @key_types)) ) {
        print "Missing or invalid value for in key type";
        return 0;
    }

    if ((!exists($opt->{"out_type"}) ) || 
        (!($opt->{"out_type"} ~~ @key_types))) {
        print "Missing or invalid value for out key type";
        return 0;
    }
    if ((!exists($opt->{"action"})) || 
        (!($opt->{"action"} ~~ @action_types)) ) {
        return 0;
    }
    return 1;
}

sub parse_input {
    my %ret;
    GetOptions(\%ret, ('in_key=s', 'in_ca_priv=s','in_ca_pub=s',
       'in_name=s', 'in_type=s', 'action=s', 'out_subj=s', 
       'out_key=s', 'out_type=s'));
    return %ret;
}

sub main() {
    my %opt = parse_input();
    my $res = check_input(\%opt);
    if (! $res ) {
        return;
    }
    signpost_transform::manage_key(\%opt)
}

main()
