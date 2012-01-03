# https://github.com/ruby/ruby/blob/trunk/ext/openssl/ossl.c#L409

require 'rubygems'
require 'openssl'

puts "Creating key for the server"

server_key = OpenSSL::PKey::RSA.new 2048
server_public_key = server_key.public_key

open 'server_private_key.pem', 'w' do |io| io.write server_key.to_pem end
open 'server_public_key.pem', 'w' do |io| io.write server_public_key.to_pem end

puts "Creating a Certificate Signing Request for the server"
# Create a request that the server must sign
name = OpenSSL::X509::Name.parse 'CN=server.probsteide.com/DC=server.probsteide.com'

csr = OpenSSL::X509::Request.new
csr.version = 0
csr.subject = name
csr.public_key = server_public_key
csr.sign server_key, OpenSSL::Digest::SHA1.new

# Write the request to disk
open 'server_csr.pem', 'w' do |io|
  io.write csr.to_pem
end


#####################
## MISC
## Opening a key
# public_key = OpenSSL::PKey::RSA.new File.read 'server_public_key.pem'

## Public encryption (Can only be decrytped with private key)
# public_encrypted = server_key.public_encrypt 'top secret document'

## Private encryption (Can only be decrytped with public-key)
# private_encrypted = server_key.private_encrypt 'top secret document'
