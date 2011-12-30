require 'thin/connection'

#  curl --cert ssl-keys/laptop.crt --key ssl-keys/laptop.key.insecure -k
#  https://localhost:8080/ -v 

module Signpost
  # Connection between the server and client.
  # This class is instanciated by EventMachine on each new connection
  # that is opened.
  class PspConnection < Thin::Connection
    # verify the ssl credentials. 
    def ssl_verify_peer(cert)
      certificate = OpenSSL::X509::Certificate.new cert
      user = certificate.subject.to_a.select{|v| (v[0] == "CN")}
      user_info = user.first[1]

      # Pass the user_info along to the application server
      # This is of course assuming the authentication has passed.
      @request.env["user_info"] = user_info

      puts "request certificate for " + user_info
      puts "Success always when credentials are provided\n"
      return true
    end


    # Make sure that when the user provides no credential tear down
    # connection
    def ssl_handshake_completed
      if (get_peer_cert == nil) 
        puts "no certificate found, terminating\n"	
        close_connection()
      end
    end
  end
end
