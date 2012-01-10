require 'thin/connection'
require 'rubygems' if "#{RUBY_VERSION}" < "1.9.0"
require 'dnsruby'

#  curl --cert ssl-keys/laptop.crt --key ssl-keys/laptop.key.insecure -k
#  https://localhost:8080/ -v 

# module Signpost
module Signpost
  # Connection between the server and client.
  # This class is instanciated by EventMachine on each new connection
  # that is opened.
  class PspConnection < Thin::Connection

    attr_accessor :user

    def pre_process
      puts "This is preprocess stage\n"
      @request.remote_address = remote_address
      @request.async_callback = method(:post_process)

      @request.env["signpost.user"] = self.user
      if cert = get_peer_cert
        @request.env['rack.peer_cert'] = cert
      end

      # When we're under a non-async framework like rails, we can still spawn
      # off async responses using the callback info, so there's little point
      # in removing this.
      response = AsyncResponse
      catch(:async) do
        # Process the request calling the Rack adapter
        response = @app.call(@request.env)
      end
      response
    rescue Exception
      handle_error
      terminate_request
      nil # Signal to post_process that the request could not be processed
    end

    # verify the ssl credentials. 
    def ssl_verify_peer(cert)
      certificate = OpenSSL::X509::Certificate.new cert
      user = certificate.subject.to_a.select{|v| (v[0] == "CN")}
      domain_path = user[0][1].split('.')
      domain_path.shift()
      domain = domain_path.join('.')+'.'
      puts domain
      verified = false
      begin 
        Dnsruby::DNS.open(:nameserver=>['127.0.0.1']) {|dns|
          dns.getresources(domain, Dnsruby::Types.DNSKEY).collect {|r|
            if((r.algorithm == Dnsruby::Algorithms::RSASHA256) || 
               (r.algorithm == Dnsruby::Algorithms::RSASHA1)) then
              if(certificate.verify(r.rsa_key())) then 
                verified = true
              end
            end
          }
        }
      rescue Dnsruby::NXDomain
        return false
      end
      return verified
    end


    # Make sure that when the user provides no credential tear down
    # connection
    def ssl_handshake_completed
      cert = get_peer_cert
      if (get_peer_cert == nil) 
        puts "no certificate found, terminating\n"
        close_connection()
      end
      certificate = OpenSSL::X509::Certificate.new cert
      self.user = certificate.subject.to_a.select{|v| (v[0] == "CN")}[0][1]
    end
  end

end
