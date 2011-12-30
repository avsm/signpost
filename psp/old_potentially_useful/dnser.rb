require './crypto'
require './keystore'
require './policer'

ENCRYPT = true

class DNSEr
  MINUTE = 60
  MINUTES = MINUTE
  HOUR = 60 * MINUTES
  KEY_TTL = 1 * HOUR
  SIGNPOST_TTL = 30 * MINUTES
  SIGNPOST_PORT = 5300
  REQUEST_TTL = 1 * HOUR

  def initialize signpost_base = "signpost.probsteide.com"
    @signpost_base = signpost_base
    @key_store = KeyStore.new
    @policer = Policer.new signpost_base, @key_store
  end

  def answer_signpost_query answer, id
    if in_our_realm? id then
      signpost_servers.map do |priority, weight, port, host|
        signpost_answer = srv_answer_for(priority, weight, port, host)
        answer.add_answer("_signpost._tcp.#{id}", SIGNPOST_TTL, signpost_answer)
      end
      answer.encode
    end
    true
  end

  def answer_key_query answer, device 
    if in_our_realm? device then
      key_answer = txt_answer_for("key=#{@key_store.key_for_local_id device}")
      answer.add_answer("signpost_key.#{device}", KEY_TTL, key_answer)
      answer.encode
    end
    true
  end

  def answer_resource_query answer, resource, id
    if (in_our_realm? resource) and (@policer.is_request_allowed? resource, id) then
      # The client's public key is used to encrypt the response
      pub_key = @key_store.key_for_remote_id id
      symmetric_crypter = Crypto::SymmetricCrypter.new
      # Symmetric key under which the responses are encrypted
      symmetric_key = symmetric_crypter.key
      asymmetrically_encrypted_symmetric_key =
        symmetric_key # TODO: Add assymetric encryption

      ticket = @policer.generate_ticket_for resource, id
      ip, port = get_ip_and_port_for resource

      resource_answer = txt_answer_for(*["issuer=#{ticket[:issuer]}",
          "client=#{ticket[:issued_for]}",
          "resource_key=#{ticket[:resource_key]}",
          "expires=#{ticket[:expires]}",
          "ip=#{symmetric_crypter.encrypt(ip)}", 
          "port=#{symmetric_crypter.encrypt(port.to_s)}",
          "key=#{asymmetrically_encrypted_symmetric_key}"])

      # Setup answer
      answer.add_answer(id, REQUEST_TTL, resource_answer)
      answer.encode
    end
    true
  end


  private
  def srv_answer_for priority, weight, port, host
    Resolv::DNS::Resource::IN::SRV.new(priority, weight, port, host) 
  end

  def txt_answer_for *text
    Resolv::DNS::Resource::TXT.new(*text)
  end

  def in_our_realm? id
    (id =~ /#{@signpost_base}$/) != nil
  end

  def get_ip_and_port_for resource
    ["127.0.0.1", 5300]
  end

  def signpost_servers
    [[0, 1, 5300, "127.0.0.1"]]
  end
end
