#!/usr/bin/env python

__author__ = 'Jan Klepek <jan.klepek@digmia.com>'

import argparse
import re
import os
import json
import requests

from docker import Client
from docker.utils import kwargs_from_env

class APIError(Exception):
    """An API Error Exception"""

    def __init__(self, status):
        self.status = status

    def __str__(self):
        return "APIError: status={}".format(self.status)

def dock_req(host = None, url = None):
	resp = requests.get(host+url)
	if resp.status_code != 200:
    	# This means something went wrong.
    		raise APIError('GET '+url+' {}'.format(resp.status_code))
	return resp.json();

class Struct:
    def __init__(self, **entries): 
        self.__dict__.update(entries)

c = Client(**(kwargs_from_env()))

containers = c.containers()
containers_out={};

# zjistime si ktore kontainery bezime a ich idcka + jmena
for k in containers:
	s = Struct(**k)
	c={};
	#print json.dumps(k)
	for labelo in s.Labels:
		if labelo == "com.docker.compose.project":
			c["name"]=s.Labels[labelo];
		elif labelo == "com.docker.compose.service":
			c["service"]=s.Labels[labelo];
	# default je ze container nebezi, tzn 0, ak bezi tak 1
	c["state"]=0
	if s.State.lower() == "running":
		c["state"]=1
	containers_out[s.Id]=c
#	print s.Id+" "+c["name"]+"-"+c["service"]


# vytiahneme si ich stats
host = "http://localhost:4500";

for k in containers_out:
	x = containers_out[k]
	print k+" "+x["name"]+"-"+x["service"]+" v stavu:"+str(x["state"])
	if (x["state"]==0):
		continue
	try:
        	stats = dock_req(host,"/containers/"+k+"/stats?stream=false")
	except APIError as error:
		print error.status;
		continue
	temp = Struct(**stats)
	print "memory usage: "+str(temp.memory_stats["usage"])
	print "memory limit: "+str(temp.memory_stats["limit"])
	cpudelta = temp.cpu_stats["cpu_usage"]["total_usage"] - temp.precpu_stats["cpu_usage"]["total_usage"] 
	systemdelta = temp.cpu_stats["system_cpu_usage"] - temp.precpu_stats["system_cpu_usage"]
	cpu_usage = cpudelta / systemdelta * 100;
	print "cpu usage: "+str(cpu_usage)
