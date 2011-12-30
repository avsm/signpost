class Policer
  def initialize signpost_id, key_store
    @signpost_id = signpost_id
    @key_store = key_store
  end

  def is_request_allowed? resource, id
    true
  end

  def generate_ticket_for resource, id
    # The public key of the resource
    resource_pub_key = @key_store.key_for_local_id resource

    symmetric_crypter = Crypto::SymmetricCrypter.new
    # Key used to encrypt the ticket
    resource_key = symmetric_crypter.key
    encrypted_resource_key = resource_key # TODO: Encrypt under resource pub-key

    ticket_data = {
      :issuer => symmetric_crypter.encrypt(@signpost_id),
      :issued_for => symmetric_crypter.encrypt("#{id} "),
      :client_key => symmetric_crypter.encrypt(@key_store.key_for_remote_id(id)),
      :expires => symmetric_crypter.encrypt(expiration_for_resource(resource).to_s),
      :resource_key => encrypted_resource_key
    }
  end
  
  def expiration_for_resource resource
    # This is obviously bullshit, but just need some test data
    (rand(Time.now.to_i) * 1000).to_i + 60 + Time.now.to_i
  end
end
