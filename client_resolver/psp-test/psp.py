#!/usr/bin/env python

from twisted.web import server, resource, http
from twisted.internet import reactor
from twisted.web.error import Error
import signpost
import json

class Singpost_server(resource.Resource):
    isLeaf = True
    _server_data = signpost.Signpost_data()

    def render_GET(self, request):
        #try:
        return self.process_request(request) 
        #except ValueError:
        #    return Error(http.NOT_FOUND, "Cannot parse data section")

    def render_POST(self, request):
        # try:
        return self.process_request(request) 
        #except ValueError:
            # TODO: this doesn't work
        #    return Error(http.NOT_FOUND, "Cannot parse data section")

    def process_request(self, request):
        path = request.postpath
        if (("content" in request.args) and 
                (len(request.args["content"]) > 0)):
            print str(request.args["content"][0])+"\n"
            data = json.loads(request.args["content"][0])
        else:
            data = {}

        if ((len(path) < 2) or (path[0].lower() != "v1")) :
            return Error(http.NOT_FOUND, "Invalid url")

        # Requesting entries from signpost server
        # curl --data 'content={"port":8080,"ip":["10.10.0.3"]}' http://10.10.0.2:8080/v1/register
        if (path[1].lower() == "register"):
            print str(data)+" "+str(request.args["content"][0])+"\n"
            if ((type(data) is dict) and ('port' in data) 
                    and ('ip' in data)):
                print ("adding server %s:%s\n"%(str(data['ip']), data['port']))
                return self._server_data.add_json_server_list(data)
            else:
                return Error(http.NOT_FOUND, "Cannot parse data section")
        
        # Requesting entries from signpost server
        if (path[1].lower() == "signpost"):
            if('data' in data):
                print ("returning server list %s\n"%(data['data']))
            return self._server_data.get_json_server_list() 

        # Adding any additional entries in the resource list for a 
        # specific device and replying with the full list of data
        elif (path[1].lower() == "resources") and (len(path) >= 3):
            domain = path[2]
            device = None
            if(len(path) >= 4):
                device = path[3]
            # Need to make this a bit more clear maybe? 
            print 'adding new entry\n' 
            if((len(data) > 0) and (self._server_data.validate_resource_list(data))):
                self._server_data.add_json_resource_list(domain, device, data)
            return self._server_data.get_json_resource_list(domain, device)
        
        return ("<html>Hello, world! %s (%d) </html>"%(path, len(path)))

def main ():

    site = server.Site(Singpost_server())
    reactor.listenTCP(8080, site)
    reactor.run()


if __name__ == "__main__":
    main()

