# for testing:
# WORKS:
# curl -d "{\"client\":{\"id\":\"valid_client\",\"signpost\":\"url\",\"key_version\":\"2\"}, \"client_shared_secret\":\"txzJ7u6UlyCKm7X+DdtQ/cW/wfIqqfC6x4AEpAJgMnHzhdSXoCtQ0MasPJ1h78yoW16EjhtJSaJSbHLr/DIWcebwSxvFDR6hFp1m+MmGZ5W7xUkmPTzou3AwDR2O1PckNKimR6TYwoxddNGSPrP4bYj1uOCby9T04dx69LUqvu+lG3/5dCeiAVp96whawWHWZ/lQVQ8bpRdNsXm9rKJ17bniUwI6g55ZaK5ZCpOlVsET+wt/mfY8PShBp89Acj949Us8qEF9pd4pj/i06VrACoKhWx3r72XkAi4pnturd3VeZNIUKthhEKZ5+zrWCmy/3pUZg5UZj/0kv0OXtp4o/A==\"}" -X POST localhost:4567/tickets
#
# FAILS:
# curl -d "{\"client\":{\"id\":\"invalid_client\",\"signpost\":\"url\",\"key_version\":\"2\"}, \"client_shared_secret\":\"txzJ7u6UlyCKm7X+DdtQ/cW/wfIqqfC6x4AEpAJgMnHzhdSXoCtQ0MasPJ1h78yoW16EjhtJSaJSbHLr/DIWcebwSxvFDR6hFp1m+MmGZ5W7xUkmPTzou3AwDR2O1PckNKimR6TYwoxddNGSPrP4bYj1uOCby9T04dx69LUqvu+lG3/5dCeiAVp96whawWHWZ/lQVQ8bpRdNsXm9rKJ17bniUwI6g55ZaK5ZCpOlVsET+wt/mfY8PShBp89Acj949Us8qEF9pd4pj/i06VrACoKhWx3r72XkAi4pnturd3VeZNIUKthhEKZ5+zrWCmy/3pUZg5UZj/0kv0OXtp4o/A==\"}" -X POST localhost:4567/tickets

require 'rubygems'
require 'sinatra'
require 'json'
require './lib/ticket_master'

post '/tickets' do
  ticket_master = TicketMaster.new

  body = JSON.parse(request.body.read)
  # Id of client that we can verify against signpost
  ticket_master.client_id = body["client"]["id"]
  # Signpost used for verification of client 
  ticket_master.signpost = body["client"]["signpost"]
  # The current key version that should be used
  ticket_master.key_version = body["client"]["key_version"]
  # Clients have of Diffie Hellman shared secret
  # It is encrypted using our public-key
  ticket_master.encrypted_client_secret = body["client_shared_secret"]

  # Get the client's public key
  if ticket_master.is_valid? then
    session = ticket_master.create_ticket
    ({
      :status => "success",
      :server_shared_secret => session[:server_shared_secret],
      :ticket_id => session[:ticket_id]
    }).to_json

  else
    ({
      :status => "failed",
      :message => "could not validate public key"
    }).to_json

  end
end
