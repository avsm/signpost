##Usage

For the client: "sudo ./client.sh server port" starts the client. localhost:port will then be tunneled to server:port over http, port 80 between the two endpoints.

For the server: "sudo ./server.sh port" starts the server. It will be listening on port 80 externally and forwarding data to `port` locally.

##Prerequisites

httptunnel (on Ubuntu: sudo apt-get install httpserver)
    
