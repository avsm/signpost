require 'rubygems'
require 'openssl'

ca_key = nil
ca_cert = nil


#####################
# Becoming a Certificate Authority
if File.exists? 'ca_cert.pem' then
  puts "Already is a CA"
  ca_key = OpenSSL::PKey::RSA.new File.read 'ca_key.pem'
  ca_cert = OpenSSL::X509::Certificate.new File.read 'ca_cert.pem'

else
  puts "Becoming a Certificate authority"

  pass_phrase = "CA PASSPHRASE"

  ca_key = OpenSSL::PKey::RSA.new 2048
  cipher = OpenSSL::Cipher::Cipher.new 'AES-128-CBC'
  open 'ca_key.pem', 'w', 0400 do |io|
    io.write ca_key.export(cipher, pass_phrase)
  end

  # Creating the CA Certificate
  ca_name = OpenSSL::X509::Name.parse 'CN=probsteide.com/DC=probsteide.com'

  ca_cert = OpenSSL::X509::Certificate.new
  ca_cert.serial = 0
  ca_cert.version = 2
  ca_cert.not_before = Time.now
  ca_cert.not_after = Time.now + 86400

  ca_cert.public_key = ca_key.public_key
  ca_cert.subject = ca_name
  ca_cert.issuer = ca_name

  extension_factory = OpenSSL::X509::ExtensionFactory.new
  extension_factory.subject_certificate = ca_cert
  extension_factory.issuer_certificate = ca_cert
  extension_factory.create_extension 'subjectKeyIdentifier', 'hash'

  # To indicate that the CA's key may be used as a CA
  extension_factory.create_extension 'basicConstraints', 'CA:TRUE', true

  # To indicate that the CA's key may be used to verify signatures on
  # both certificates and certificate recovations.
  extension_factory.create_extension 'keyUsage', 'cRLSign,keyCertSign', true

  # Self sign the certificate
  ca_cert.sign ca_key, OpenSSL::Digest::SHA1.new

  open 'ca_cert.pem', 'w' do |io|
    io.write ca_cert.to_pem
  end

end




#####################
## Sign a CSR for the client
puts "Starting signing process for client"
csr = OpenSSL::X509::Request.new File.read 'client_csr.pem'
raise 'CSR can not be verified' unless csr.verify csr.public_key

puts "Verfied authenticity of signing request"
csr_cert = OpenSSL::X509::Certificate.new
csr_cert.serial = 0
csr_cert.version = 2
csr_cert.not_before = Time.now
csr_cert.not_after = Time.now + 3600
csr_cert.subject = csr.subject
csr_cert.public_key = csr.public_key
csr_cert.issuer = ca_cert.subject

extension_factory = OpenSSL::X509::ExtensionFactory.new
extension_factory.subject_certificate = csr_cert
extension_factory.issuer_certificate = ca_cert
extension_factory.create_extension 'basicConstraints', 'CA:FALSE'
extension_factory.create_extension 'keyUsage', 'keyEncipherment,dataEncipherment,digitalSignature'
extension_factory.create_extension 'subjectKeyIdentifier', 'hash'

csr_cert.sign ca_key, OpenSSL::Digest::SHA1.new

open 'client_cert.pem', 'w' do |io|
  io.write csr_cert.to_pem
end




#####################
## Sign a CSR for the server
puts "Starting signing process for server"
csr = OpenSSL::X509::Request.new File.read 'server_csr.pem'
raise 'CSR can not be verified' unless csr.verify csr.public_key

puts "Verfied authenticity of signing request"
csr_cert = OpenSSL::X509::Certificate.new
csr_cert.serial = 0
csr_cert.version = 2
csr_cert.not_before = Time.now
csr_cert.not_after = Time.now + 3600
csr_cert.subject = csr.subject
csr_cert.public_key = csr.public_key
csr_cert.issuer = ca_cert.subject

extension_factory = OpenSSL::X509::ExtensionFactory.new
extension_factory.subject_certificate = csr_cert
extension_factory.issuer_certificate = ca_cert
extension_factory.create_extension 'basicConstraints', 'CA:FALSE'
extension_factory.create_extension 'keyUsage', 'keyEncipherment,dataEncipherment,digitalSignature'
extension_factory.create_extension 'subjectKeyIdentifier', 'hash'

csr_cert.sign ca_key, OpenSSL::Digest::SHA1.new

open 'server_cert.pem', 'w' do |io|
  io.write csr_cert.to_pem
end
