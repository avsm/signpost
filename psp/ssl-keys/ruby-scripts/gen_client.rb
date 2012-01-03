require 'rubygems'
require 'openssl'

puts "Creating key for the client"

client_key = OpenSSL::PKey::RSA.new 2048
client_public_key = client_key.public_key

open 'client_private_key.pem', 'w' do |io| io.write client_key.to_pem end
open 'client_public_key.pem', 'w' do |io| io.write client_public_key.to_pem end

puts "Creating a Certificate Signing Request"
# Create a request that the server must sign
name = OpenSSL::X509::Name.parse 'CN=macbook.probsteide.com/DC=macbook.probsteide.com'

csr = OpenSSL::X509::Request.new
csr.version = 0
csr.subject = name
csr.public_key = client_public_key
csr.sign client_key, OpenSSL::Digest::SHA1.new

# Write the request to disk
open 'client_csr.pem', 'w' do |io|
  io.write csr.to_pem
end

# Done...
puts "Done..."
