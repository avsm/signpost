class KeyStore
  def self.get_client_key(client_id, key_version, client_signpost)
    # Return from local cache if it exists
    return File.absolute_path("client_pub.pem",
        File.join(File.dirname(__FILE__), "..", "keys"))

    # Contact the signpost, get the key. Validate chain of trust.
    # TODO: Implement
  end
end
