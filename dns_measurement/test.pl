#!/usr/bin/perl

use strict;
use Net::DNS;
use Net::DNS::Update;
use Net::DNS::SEC;

my $zone = "d3.signpo.st";

# Create the update packet.
my $update = Net::DNS::Packet->new("d3.signpo.st", "MX", "IN");

# Add an A record for the name.
#$update->push(update => rr_add("aa.d3.signpo.st. 120 A 127.0.0.8"));
$update->push(additional => rr_add("aa.d3.signpo.st. 120 A 127.0.0.8"));

# Sign the update packet
$update->sign_sig0( "Ksp.+003+03490.private");

# Send the update to the zone's primary master.
my $res = Net::DNS::Resolver->new;
$res->nameservers('8.8.8.8');

my $reply = $res->send($update);

# Did it work?
if ($reply) {
     if ($reply->header->rcode eq 'NOERROR') {
         print "Update succeeded\n";
     } else {
         print 'Update failed: ', $reply->header->rcode, "\n";
     }
} else {
     print 'Update failed: ', $res->errorstring, "\n";
}

