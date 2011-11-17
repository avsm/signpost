import json

# TODO: a method to check if a string if an ip is valid

class Signpost_data():
    def __init__(self):
        self._servers = []

        # format {'device_name': 
        # {'ip_num':
        # {'port_num':'process_name'} } }
        self._service = {}

    def add_json_server_list(self, data):
        for ip in data['ip']:
            if( not ({'ip':ip, 'port':data['port']} in self._servers)):
                self._servers.append({'ip':ip, 'port':data['port']})
        return json.dumps({'result':1})

    def get_json_server_list(self):
        return json.dumps(self._servers)

    def validate_resource_list(self, data):
        ''' Check if the format of the data 
        is valid for processing '''
        if not (type(data) is list ):
            print "validate_resource_list: data is not a list\n"
            return False
        for rec in data:
            if( (not (type(rec) is dict)) or
                    ('ip' not in rec) or
                    ('process_name' not in rec) or
                    ('port' not in rec)):
                        print "validate_resource_list: record misses a field\n"
                        return False
        return True

    def add_json_resource_list(self, domain, device, data):
        for service in data:
            print ("adding service %s (%s:%d)\n" % (service['process_name'], 
                service['ip'], service['port']))
            if (device not in self._service):
                self._service[device] = {}
            dev_obj = self._service[device]

            if(service['ip'] not in self._service[device]):
                 dev_obj[service['ip']] = {}
            ip_obj = dev_obj[service['ip']]

            ip_obj[service['port']] = service['process_name']

        return json.dumps({'status':1})

    def get_json_resource_list(self, domain, device):
        return json.dumps(self._service)
