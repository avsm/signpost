require 'openssl'
require 'base64'

module Crypto
  # Pub-key encryption and decryption by:
  # http://stuff-things.net/2007/06/11/encrypting-sensitive-data-with-ruby-on-rails/
  class AssymetricCrypter
    # Key must be stored out of the root... this is ugly
    PRIVATE_KEY_FILE = File.absolute_path("server.pem",
        File.join(File.dirname(__FILE__), "..", "keys"))
    # Need to find a good place to store this password.
    PRIVATE_KEY_PASSWORD = "server"

    def decrypt_private encrypted_msg 
      private_key = OpenSSL::PKey::RSA.new(File.read(PRIVATE_KEY_FILE), PRIVATE_KEY_PASSWORD)
      private_key.private_decrypt(Base64.decode64(encrypted_msg))
    end

    def encrypt_for_public_key msg, public_key_file
      public_key = OpenSSL::PKey::RSA.new(File.read(public_key_file))
      Base64.encode64(public_key.public_encrypt(msg))
    end

    def shared_secret(client_secret, server_secret)
      "#{client_secret}-#{server_secret}"
    end
  end

  # Symmetric key encryption by https://alangano.com/node/4
  class SymmetricCrypter
    CIPHER_NAME = 'aes-128-cbc'

    def initialize
      @cipher = OpenSSL::Cipher::Cipher.new(CIPHER_NAME)
      @cipher.padding = 1
      @cipher.key = key
    end

    def encrypt text
      return text unless ENCRYPT
      @cipher.encrypt
      @cipher.iv = OpenSSL::Random.random_bytes(@cipher.iv_len)
      encrypted_text = @cipher.update(text)
      encrypted_text << @cipher.final
      Base64.strict_encode64(encrypted_text)
    end

    def decrypt base64_encrypted_text
      return base64_encrypted_text unless ENCRYPT
      @cipher.decrypt
      @cipher.iv = OpenSSL::Random.random_bytes(@cipher.iv_len)
      text = @cipher.update(Base64.strict_decode64(base64_encrypted_text))
      text << @cipher.final
      text
    end

    # If a key hasn't been set, we generate one
    def key
      @key ||= generate_key
    end

    # For decryption we want to be able to set a key
    def key= new_key
      @key = new_key
      @cipher.key = key
    end

    private
    def generate_key
      OpenSSL::Random.random_bytes(@cipher.key_len)
    end
  end
end
