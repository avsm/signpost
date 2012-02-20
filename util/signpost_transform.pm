package signpost_transform;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(manage_key);  # symbols to export on request

use Net::DNS::RR;
use Net::DNS;
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::Bignum;
use Net::DNS::SEC::Private;
use Crypt::OpenSSL::CA;

# used to print nicely the date on the certificate
use POSIX;

use strict;

sub construct_rsa_key {
# Implementation using crypt::openssl                                                    
	my ($keyrr) = @_;                                   
# RSA RFC2535                                                                            
#                                                                                        

	my $explength;                                                                           
	my $exponent;                                                                            
	my $modulus;                                                                             
	my $RSAPublicKey;                                                                        

	{   #localise dummy                                                                      
		my $dummy=1;                                                                         
# determine exponent length                                                          
#RFC 2537 sect 2                                                                     
		($dummy, $explength)=unpack("Cn",$keyrr->keybin)                                     
			if ! ($explength=unpack("C",$keyrr->keybin));                                    

# We are constructing the exponent and modulus as a hex number so                    
# the AUTOLOAD function in Crypt::RSA::Key::Public can deal with it                  
# later, there must be better ways to do this,                                       
		if ($dummy) { # skip one octet                                                       
			$exponent=(substr ($keyrr->keybin, 1, $explength));                                                 
			$modulus=( substr ($keyrr->keybin,  1+$explength,                                    
						(length $keyrr->keybin) - 1 - $explength));                                               
		}else{ # skip two octets                                                             
			$exponent=(substr ($keyrr->keybin,3, $explength));                                                 

			$modulus=( substr ($keyrr->keybin, 3+$explength,
						(length $keyrr->keybin) - 3 - $explength));                                               
		}
	} 


	my $bn_modulus=Crypt::OpenSSL::Bignum->new_from_bin($modulus);
	my $bn_exponent=Crypt::OpenSSL::Bignum->new_from_bin($exponent);

	my $rsa_pub = Crypt::OpenSSL::RSA->new_key_from_parameters($bn_modulus,$bn_exponent);

	die "Could not load public key" unless $rsa_pub;
	return $rsa_pub;                                         
}

sub load_in_keys {
	my $opt = shift;
	my @in_keys;
	my $in_key;

	my $dnskey;
# load input key
	if ($opt->{"in_type"} eq "dns_pub") {
		if (exists($opt->{"in_key"})) {
# right here code to parse an rsa public key
			open(FILE, $opt->{"in_key"}) or die("Fialed to open file " .
					$opt->{"in_key"});
			while(<FILE>) {
				if(! /^;/) {
					print $_;
					$dnskey = Net::DNS::RR->new($_);
					last;
				}
			}
			$in_key = construct_rsa_key($dnskey);
			print $in_key->get_public_key_string() . "\n";
			push @in_keys, $in_key; 
		} elsif (exists($opt->{"in_name"})) {
			print "looking up name " . $opt->{"in_name"} . "\n";
			my $res = Net::DNS::Resolver->new(config_file => '/etc/resolv.conf');
			my $packet = $res->search($opt->{"in_name"}, 'DNSKEY');
			my @answer = $packet->answer;
			foreach my $rr (@answer) {
				if($rr->type eq "DNSKEY") {
					my $in_key =  construct_rsa_key($rr);
					print $in_key->get_public_key_string() . "\n";
					push @in_keys, $in_key;
				}
			}
		}
	} elsif ($opt->{"in_type"} eq "dns_priv") {
		if(exists($opt->{"in_key"})) {
			$in_key = Net::DNS::SEC::Private->new($opt->{"in_key"});
			# ->private;
			#--------------------------------------------------
			# foreach (keys %{$in_key}) {
			# 	print "$_ ".($in_key->{$_})."\n";
			# }
			#-------------------------------------------------- 
			push @in_keys, ($in_key->privatekey);
		}
	} elsif ($opt->{"in_type"} eq "pem_priv") {
		open my $fh, '<', $opt->{"in_key"} or die "error opening ".$opt->{"in_key"}.": $!";
		my $data = do { local $/; <$fh> };
		$in_key = Crypt::OpenSSL::RSA->new_private_key($data);
		push @in_keys, ($in_key);
	} elsif ($opt->{"in_type"} eq "pem_pub") { 
		open my $fh, '<', $opt->{"in_key"} or die "error opening ". $opt->{"in_key"}.": $!";
		my $data = do { local $/; <$fh> };
		$in_key = Crypt::OpenSSL::RSA->new_public_key($data);
		push @in_keys, ($in_key);
	}
	
	return \@in_keys
}

sub transform_key {
	my $opt = shift;
	my $in_keys = load_in_keys($opt);
	
	if ($opt->{"out_type"} eq "pem_priv") {
		foreach my $key (@{$in_keys}) {
			if($key->is_private) {
				open(FILE, '>', $opt->{"out_key"});
				print FILE $key->get_private_key_string();
				close(FILE);
			}
		}
	} elsif ($opt->{"out_type"} eq "pem_pub") {
			foreach my $key (@{$in_keys}) {
				open(FILE, '>', $opt->{"out_key"});
				print FILE $key->get_public_key_x509_string();
				close(FILE);
		}
	} else {
		print "Script does not support out type ". $opt->{"out_type"}. "\n";
	}
	return 1;
}

sub sign_key {
	my $opt = shift;
	my %cert_det;
	print "out subject ". $opt->{"out_subj"}. "\n";
	my @entries = split(";", $opt->{"out_subj"}); 
	foreach my $entry (@entries) {
		if($entry =~ /(.*)=(.*)/) {
			print "$1 $2\n";
			$cert_det{$1} = $2;
		}
	}

	# load the public or private in keys
	my $in_keys = load_in_keys($opt);
	foreach my $key ( @{$in_keys}) {
		print $key->get_public_key_x509_string();
		my $pub_key = Crypt::OpenSSL::CA::PublicKey->parse_RSA($key->get_public_key_x509_string());
		my $x509 = Crypt::OpenSSL::CA::X509->new($pub_key);
		# beware the fields must be in a proper sequence
		$x509->set_subject_DN(Crypt::OpenSSL::CA::X509_NAME->new(%cert_det));

		my $issuer_name;
		if(exists($opt->{"in_ca_cert"})) {
			print "loading issuer details from cert file\n";
			open my $fh, '<', $opt->{"in_ca_cert"} or die "error opening ". $opt->{"in_ca_cert"} .": $!";
			my $data = do { local $/; <$fh> };
			$issuer_name = Crypt::OpenSSL::CA::X509->parse($data)->get_subject_DN();
		} else {
			print "no ca cert is provided, assume the cert is self signed\n";
			$issuer_name = Crypt::OpenSSL::CA::X509_NAME->new(%cert_det);
		}

		$x509->set_issuer_DN($issuer_name);
		
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		$x509->set_notBefore(POSIX::strftime("%Y%m%d%H%M%SZ", $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst));
		$x509->set_notAfter (POSIX::strftime("%Y%m%d%H%M%SZ", $sec,$min,$hour,$mday,$mon,($year+1),$wday,$yday,$isdst));
		
		open my $fh, '<', $opt->{"in_ca_priv"} or die "error opening ". $opt->{"in_ca_priv"} .": $!";
		my $data = do { local $/; <$fh> };
		print "Public key loaded\n";
		print $data;
		my $sign_key = Crypt::OpenSSL::CA::PrivateKey->parse($data);
		print "Public key loaded\n";
		my $crt = $x509->sign ( $sign_key, "sha1");
		print $x509->dump();
		open(FILE, '>', $opt->{"out_key"});
		print FILE $crt;
		close(FILE);
}
	# Crypt::OpenSSL::CA::X509->new()
}

sub manage_key {
	my $opt = shift;

	if($opt->{"action"} eq "sign") {
		print "signing input key\n";
				return sign_key($opt);	
	} elsif ($opt->{"action"} eq "transform") {
		print "transform input to output type\n";
		return transform_key($opt);
	} elsif ($opt->{"action"} eq "verify") {
		print "verify input certificate is signed by ca public key\n";
		print "not implemented yet\n";
	} else {
		print "Invalid action, aborting\n";
		return 0;
	}
}

return 1; 
