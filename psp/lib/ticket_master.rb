require 'digest/sha1'
$:.unshift File.dirname(__FILE__)
require 'key_store'
require 'crypto'

class TicketMaster
  attr_accessor :client_id, :signpost, :key_version, :encrypted_client_secret

  # Check that we can get the clients public key and verify its validity
  def is_valid?
    # Verify that we have a client key
    client_key_location != nil
    # Dummy version, for testing:
    @client_id == "valid_client"
  end

  # Sets up a session for the given user
  def create_ticket
    ticket_id = "1234" # Create and store somewhere...
    params = {
      :server_shared_secret => encrypted_server_secret,
      :ticket_id => ticket_id
    }

    # return the parameters
    params
  end


private
  # Get the encrypted version of the servers shared secret
  def encrypted_server_secret
    Crypto::encrypt_for_public_key server_secret, client_key_location
  end

  # private
  # Get the server half of the shared secret
  def server_secret
    @server_secret ||= Random.rand(99999).to_s + Time.now.to_s
    Digest::SHA1.hexdigest @server_secret
  end

  def client_secret
    @client_secret ||= Crypto::decrypt_private @encrypted_client_secret
    @client_secret
  end

  def client_key_location
    @client_key_location ||= KeyStore::get_client_key @client_id, @key_version, @signpost
    @client_key_location
  end
end
