1) Converting dnssec private key to pem private key

./key_convert.pl --in_key=dnnsec-key --in_type=dns_priv --action=transform --out_type=pem_priv --out_key=dnssec-key.pem

2) Extract pem public key from pem public key

./key_convert.pl --in_key=ca.pem --in_type=pem_priv --action=transform --out_type=pem_pub --out_key=ca.pub

3) create a self-signed certificate

./key_convert.pl --in_key=ca.pem  --in_type=dns_priv --in_ca_priv=ca.pem --action=sign --out_type=pem_cert --out_key=ca.cert --out_subj="CN=signpo.st;C=uk;"
