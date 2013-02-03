#!/usr/bin/python
from gearman import GearmanWorker
import json
from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver
from boto.ec2.connection import EC2Connection

import libcloud.security
import logging
logging.basicConfig(filename="/var/lib/skysql/log/boto.log", level=logging.DEBUG)

# The function that will do the work
def add_vcloud_node(worker, job):
   print job.data
   vcloud = get_driver(Provider.VCLOUD)
   driver = vcloud('skysql@David_CHANIAL_1001895', '!davixx#',
               host='vcloud.hegerys.com', api_version='1.5')
   nodes=driver.list_nodes()
   print nodes
   return job.data

def cloud_cmd(worker, job): 
   print job.data
   config=json.loads(job.data) 
   print config
   res ='000000' 
   print config['command'] 
   
   print config['command']['action'] 

   if config["command"]["action"] == "launch": 
       print "launch instance .."
       res=launching_ec2_instances(config) 
 
   if config["command"]["action"] == "status": 
       print "status instances .."  
       res=status_ec2_instances(config) 

   if config["command"]["action"] == "start": 
       print "start instance .."  + config["command"]["group"]
       res=start_ec2_instances(config)

   if config["command"]["action"] == "stop": 
       print "stop instance .."  + config["command"]["group"]
       res=stop_ec2_instances(config) 

   if config["command"]["action"] == "terminate": 
       terminate_ec2_adresse(config) 
    
   if config["command"]["action"] == "associate": 
       associate_ec2_adresse(config) 
       
   if config["command"]["action"] == "disassociate": 
       disassociate_ec2_adresse(config)  
   
   print res   
   return res

def stop_ec2_instances(config):
   import boto
   conn = boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1) 
   res=conn.stop_instances(instance_ids=[config["command"]["group"]]) 
   for i in res:
      d.append({'id' : i.id , 'ip' : i.private_ip_address, 'state' : i.state}) 
   return json.dumps(d)


def start_ec2_instances(config):
   import boto
   conn = boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)   
   res=conn.start_instances(instance_ids=[config["command"]["group"]]) 
   d=[] 
   for i in res:
      d.append({'id' : i.id , 'ip' : i.private_ip_address, 'state' : i.state}) 
   return json.dumps(d)


def terminate_ec2_instances(config):
   import boto
   conn = boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)   
   res=conn.terminate_instances(instance_ids=[config["command"]["group"]])  
   return json.dumps(res)


def status_ec2_instances(config):
    import boto
    #boto.config.set('Boto','http_socket_timeout','20')  
    import simplejson as json 
    conn = boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)    
    print "ici3"
    reservations=conn.get_all_instances()
    #adresses=get_all_network_interfaces(allocation_id=[config["cloud"]["elastic_ip_id"]])
    #adresses=get_all_network_interfaces()
    import pprint 
    
    d= [] 
    #pp.pprint(adresses)
    for reservation in reservations:
       for i in reservation.instances:
          d.append({i.id : {'id' : i.id , 'ip' : i.private_ip_address, 'state' : i.state, 'interface' : i.networkInterfaceId, 'reservation' : reservation.id }})   
    return  json.dumps(d)

def associate_ec2_adresse(config):
    import boto
    conn =boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)       
    conn.associate_address(allocation_id=config["cloud"]["elastic_ip_id"], network_interface_id=config["instance"]["interface"], allow_reassociation=True)
    conn.attach_network_interface(  network_interface_id=config["cloud"]["interface_vip_id"],instance_id=config["instance"]["id"] , device_index=1 )    
    #instance_id=config["instance"]["id"]
    
    return 1

def disassociate_ec2_adresse(config):
    import boto
    
    conn =boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)       
    #conn.disassociate_address( allocation_id=config["cloud"]["elastic_ip_id"])
    #conn.release_address(allocation_id=config["cloud"]["elastic_ip_id"])
    print "ici"
    filters = {'private_ip_address': '10.0.0.10'} 
    addresses =conn.get_all_network_interfaces(filters=filters)
    from pprint import pprint
    for i in addresses:
        print i.attachment.id
        conn.detach_network_interface( i.attachment.id )    
        print "icitest"
    
    return 1

def launching_ec2_instances(config):
   import boto
   conn =boto.connect_ec2(aws_access_key_id=config["cloud"]["user"],aws_secret_access_key=config["cloud"]["password"],debug=1)    
   
   reservation = conn.run_instances( config["cloud"]["template"] ,
        key_name=config["cloud"]["key"],
        subnet_id=config["cloud"]["subnet"],
        instance_type=config["cloud"]["instance_type"],
        security_group_ids=[ config["cloud"]["security_groups"]], 
        private_ip_address=config["command"]["ip"],
        placement=config["cloud"]["zone"])
   i = reservation.instances[0] 
   status = i.update()
   while status == 'pending':
      time.sleep(10)
      print('waiting 10s... ')
      status = i.update()
   if status == 'running':
      print('running adding tag... ')
      conn.create_tags([i.id], {"Name": config["command"]["group"]})
      # i.add_tag("Name","{{ScambleDB}}")
   else:
      print('Instance status: ' + status)
    
   #     security_groups=[ config["cloud"]["security_groups"]])
   
   return json.dumps(reservation)    

# Establish a connection with the job server on localhost--like the client,
# multiple job servers can be used.
worker = GearmanWorker(['127.0.0.1:4731'])

# register_task will tell the job server that this worker handles the "echo"
# task
worker.register_task('cloud_cmd', cloud_cmd)

# Once setup is complete, begin working by consuming any tasks available
# from the job server
print 'working...'
worker.work()


