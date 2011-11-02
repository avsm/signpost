# Encryption and decryption inspired by:
# http://stuff-things.net/2007/06/11/encrypting-sensitive-data-with-ruby-on-rails/
require 'openssl'
require 'base64'

class Crypto
  # Key must be stored out of the root... this is ugly
  PRIVATE_KEY_FILE = File.absolute_path("server.pem",
      File.join(File.dirname(__FILE__), "..", "keys"))
  # Need to find a good place to store this password.
  PRIVATE_KEY_PASSWORD = "server"

  def self.decrypt_private encrypted_msg 
    private_key = OpenSSL::PKey::RSA.new(File.read(PRIVATE_KEY_FILE), PRIVATE_KEY_PASSWORD)
    private_key.private_decrypt(Base64.decode64(encrypted_msg))
  end

  def self.encrypt_for_public_key msg, public_key_file
    public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
    Base64.encode64(public_key.public_encrypt(msg))
  end

  def self.shared_secret(client_secret, server_secret)
    "#{client_secret}-#{server_secret}"
  end
end
