#!/usr/bin/env python

import logging, sys, psutil
import socket

class Server_discovery():
  def __init__(self, logger):
    self._service_cache = []
    self._logger = logger

  def service_update(self):
    self._logger.info("server_discovery: lookup services")
    local_cache = []
    for pid in psutil.get_pid_list():
      p = psutil.Process(pid)

      # discover listening sockets
      for conn in p.get_connections():
        if (conn.family == socket.AF_INET):
          if ((conn.type == socket.SOCK_STREAM) and 
            (conn.status == "LISTEN")):
            entry = {'name':p.name, 'ip':conn.local_address[0], 
                     'port':conn.local_address[1], 'type':'tcp'}
            local_cache.append(entry)
          elif (conn.type == socket.SOCK_DGRAM):
            entry = {'name':p.name, 'ip':conn.local_address[0], 
                     'port':conn.local_address[1], 'type':'udp'}
            local_cache.append(entry)
      
    #compare the two lists
    for entry in self._service_cache:
      if entry not in local_cache:
        self._logger.info("server_discovery: service terminated %s"%(str(entry)))
        self._service_cache.remove(entry)
      else:
        local_cache.remove(entry)

    for entry in local_cache:
      self._logger.info("server_discovery: service dscovered %s"%(str(entry)))
      self._service_cache.append(entry)
    
    return True

def main():
  logger = logging.getLogger('psp')
  hdlr = logging.FileHandler('psp.log')
  strm_out = logging.StreamHandler(sys.__stdout__)
  formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
  hdlr.setFormatter(formatter)
  strm_out.setFormatter(formatter)
  logger.addHandler(hdlr) 
  logger.addHandler(strm_out) 
  logger.setLevel(logging.INFO) 
 
  obj = Server_discovery(logger)
  obj.service_update()
  import time
  time.sleep(10)
  obj.service_update()

if __name__ == "__main__" :
  main()
