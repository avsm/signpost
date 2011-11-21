#!/usr/bin/env python

from twisted.web import server
from twisted.web import resource, http
from twisted.web.error import Error
import signpost
import json

class Singpost_server(resource.Resource):

  def __init__(self, logger):
    self.isLeaf = True
    self._server_data = signpost.Signpost_data(logger)
    self._logger = logger

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
      data = json.loads(request.args["content"][0])
    else:
      data = {}

    if ((len(path) < 2) or (path[0].lower() != "v1")) :
      return Error(http.NOT_FOUND, "Invalid url")

    # Requesting entries from signpost server
    # curl --data 'content={"port":8080,"ip":["10.10.0.3"]}' \
    # http://10.10.0.2:8080/v1/register
    if (path[1].lower() == "register"):
      self._logger.info("[%s] signpost_register : %s"%(
        str(request.getClientIP()), str(data)))
      if ((type(data) is dict) and ('port' in data) 
          and ('ip' in data)):
        return self._server_data.add_json_server_list(data)
      else:
        self._logger.error("[%s] signpost_register: Cannot parse data section")
        return Error(http.NOT_FOUND, "Cannot parse data section")
        
      # Requesting entries from signpost server
      if (path[1].lower() == "signpost"):
        if('data' in data):
          self._logger.info("[%s]:signpost_list_request"%(str(request.getClientIP())))
          return self._server_data.get_json_server_list() 

    # Adding any additional entries in the resource list for a 
    # specific device and replying with the full list of data
    elif (path[1].lower() == "resources") and (len(path) >= 3):
      domain = path[2]
      device = None
      if(len(path) >= 4):
        device = path[3]
        # Need to make this a bit more clear maybe? 
        if((len(data) > 0) and (self._server_data.validate_resource_list(data))):
          self._server_data.add_json_resource_list(domain, device, data)
          self._logger.info("[%s] add_resource : %s"%(str(data)))
          return self._server_data.get_json_resource_list(domain, device)
    
    else:
      self._logger.info("[%s] invalid service request %s"%(
        str(request.getClientIP()), str(path)))
      return ("<html>Hello, world! %s (%d) </html>"%(path, len(path)))

    def server_loop(self):
      site = server.Site(self)
      reactor.listenTCP(8080, site)
      reactor.run()
    
    def run(self):
      self.server_loop()

def main ():
    #init logger
    logger = logging.getLogger('psp')
    hdlr = logging.FileHandler('psp.log')
    strm_out = logging.StreamHandler(sys.__stdout__)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    hdlr.setFormatter(formatter)
    strm_out.setFormatter(formatter)
    logger.addHandler(hdlr) 
    logger.addHandler(strm_out) 
    logger.setLevel(logging.WARNING) 
    
    # organise the message handling functionality 
    serv = Singpost_server(logger)
    serv.server_loop()

if __name__ == "__main__":
    main()

