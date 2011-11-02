#!/usr/bin/env ruby

require 'openssl'
require 'base64'

public_key_file = 'server_pub.pem';
string = 'client_secret';

public_key =
   OpenSSL::PKey::RSA.new(File.read(public_key_file))
encrypted_string =
   Base64.encode64(public_key.public_encrypt(string))

print encrypted_string, "\n"
