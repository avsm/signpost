#!/usr/bin/env python

import dbus, gobject, avahi
import logging, sys
from dbus import DBusException
from dbus.mainloop.glib import DBusGMainLoop
import dbus.mainloop.glib

class Mdns_client:
  def __init__ (self, name, domain, port, logger):
    self._avahi = None
    self._type = '_signpost._tcp'        
    self._server = None
    self._local_psp = {}
    self._name = name
    self._domain = domain
    self._port = port
    self._logger = logger 
    self._join_cb = []
    self._leave_cb = []
    self._group = None

  def register_callback(self, typ, cb):
    '''a method to register callbacks for mdns service events'''
    if(typ.lower() == "join"): 
      self._join_cb.append(cb)
    elif(typ.lower() == "leave"):
      self._leave_cb.append(cb)
    else:
      self._logger.error("mdns:register callback %s failed"%(typ));

  def service_resolved(self, *args):
    '''lookup the service details for a given named service'''
    if(args[2] not in  self._local_psp):
      self._local_psp[args[2]] = {}

    if(args[0] not in self._local_psp.keys()):
      self._local_psp[args[2]][args[0]] = ({'port':args[8], 'address':args[7]})
      self._logger.info('mdns:adding service %s [%s-%d]'%(args[2],args[7],args[8]))
      
      for cb in self._join_cb:
        cb(args[2], args[0])
      # self._logger.info('service resolved %s'%(str(args)))

  def print_error(self, *args):
    '''logs occuring error during service lookup'''
    self._loger.error('mdns: %s'%(args[0]))

  def add_signpost(self, interface, protocol, name, stype, domain, flags):
    ''' A method that captures the event of the introduction of an avahi based service'''
    if flags & avahi.LOOKUP_RESULT_LOCAL:
    # local service, ski
      pass

    self._logger.info("mdns: add %s [intf %s, domain %s]" % 
      (name, str(interface), domain))
    self._server.ResolveService(interface, protocol, name, stype, 
        domain, avahi.PROTO_INET, dbus.UInt32(0), 
        reply_handler=self.service_resolved, error_handler=self.print_error)

  def remove_signpost(self, interface, protocol, name, stype, domain, flags):
    ''' A method that captures the event of the revocation of an avahi based service'''
    if ((name in self._local_psp.keys()) and 
      interface in self._local_psp[name].keys()):
      del  self._local_psp[name][interface]
      self._logger.info("mdns: rem %s [domain %s, intf %s]" 
        % (name, domain, str(interface)))
    for cb in self._leave_cb:
      cb(name, interface)

  def entry_group_state_changed(self, state, error):
    self._logger.info("mdns: published state change: %i" % state)
    if state == avahi.ENTRY_GROUP_ESTABLISHED:
        self._logger.info("mdns: Service established.")
    elif state == avahi.ENTRY_GROUP_COLLISION:
      self._logger.error("mdns: Service name collision, aborting")
      self.exit(1)
    elif state == avahi.ENTRY_GROUP_FAILURE:
      self._logger.error("mdns: Error in group state changed %s"%(str(error)))
      sys.exit(1)
    return
    
  def setup_mdns(self):
    '''The main loop of the method that implements all the listeing code
      in the background'''
    self._logger.info('mdns: Starting the avahi browsing service...')
    loop = DBusGMainLoop()
    bus = dbus.SystemBus(mainloop=loop)

    # getting a pointer to the avahi server through dbus
    self._server = dbus.Interface( bus.get_object(avahi.DBUS_NAME, '/'),
      'org.freedesktop.Avahi.Server')

    # browsing only for ipv4 addresses
    sbrowser = dbus.Interface(bus.get_object(avahi.DBUS_NAME,
      self._server.ServiceBrowserNew(avahi.IF_UNSPEC,
      avahi.PROTO_INET, self._type, 'local', dbus.UInt32(0))),
      avahi.DBUS_INTERFACE_SERVICE_BROWSER)
    sbrowser.connect_to_signal("ItemNew", self.add_signpost)
    sbrowser.connect_to_signal("ItemRemove", self.remove_signpost)

    # advertising the service name 
    if self._group is None:
      self._group = dbus.Interface( bus.get_object( avahi.DBUS_NAME, 
        self._server.EntryGroupNew()), avahi.DBUS_INTERFACE_ENTRY_GROUP)
      self._group.connect_to_signal('StateChanged', self.entry_group_state_changed)
    
    # register callbacks for join and leave events
    self._group.AddService(avahi.IF_UNSPEC, avahi.PROTO_INET,dbus.UInt32(0),
      self._name, self._type, "", "", dbus.UInt16(self._port), 
      ("signpost for service %s.%s"%(self._name, self._domain)))
    self._group.Commit()

    
#some simple testing methods

def leave_cb(name, intf):
  print ("leaving service %s on %s"%(name, str(intf)))

def main() : 
  # initialiaze logging mechanism
  logger = logging.getLogger('psp')
  strm_out = logging.StreamHandler(sys.__stdout__)
  hdlr = logging.FileHandler('mdns.log')
  formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
  hdlr.setFormatter(formatter)
  strm_out.setFormatter(formatter)
  logger.addHandler(hdlr)
  logger.addHandler(strm_out)
  logger.setLevel(logging.INFO) 

  mdns_client = Mdns_client('laptop', 'haris.sp', 8080, logger)
  mdns_client.register_callback("leave", leave_cb)
  mdns_client.setup_mdns()
  
  # run the loop
  gobject.threads_init()
  gobject.MainLoop().run() 
 

if __name__ == "__main__":
        main()

