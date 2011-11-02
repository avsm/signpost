#!/usr/bin/env ruby

require 'openssl'
require 'base64'

private_key_file = 'server.pem';
password = 'server'

encrypted_string = %Q{
txzJ7u6UlyCKm7X+DdtQ/cW/wfIqqfC6x4AEpAJgMnHzhdSXoCtQ0MasPJ1h78yoW16EjhtJSaJSbHLr/DIWcebwSxvFDR6hFp1m+MmGZ5W7xUkmPTzou3AwDR2O1PckNKimR6TYwoxddNGSPrP4bYj1uOCby9T04dx69LUqvu+lG3/5dCeiAVp96whawWHWZ/lQVQ8bpRdNsXm9rKJ17bniUwI6g55ZaK5ZCpOlVsET+wt/mfY8PShBp89Acj949Us8qEF9pd4pj/i06VrACoKhWx3r72XkAi4pnturd3VeZNIUKthhEKZ5+zrWCmy/3pUZg5UZj/0kv0OXtp4o/A==
}

private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file),password)

string = private_key.private_decrypt(Base64.decode64(encrypted_string))

print string, "\n"
