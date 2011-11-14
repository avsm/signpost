# Personal signpost

## Dependencies

Please use bundler to install the dependencies:

	gem install bundler
	bundler install

## Parts

There are two parts to the Personal Signpost at present.
A DNS server that resolves queries and issues tickets, 
and a RESTful webservice for updating the location of
clients.

*This is a work in progress, if you ever saw one, so please don't
build on this, unless you are willing to change things later.*

### DNS Server

For testing:
Run

	ruby dns_server.rb

and then issue requests using

	ruby resolver.rb
