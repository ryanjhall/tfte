#!/bin/bash
#
 # SET VARIABLES
#
COUNT=$1
HOST=$2

#
 # INSTALL PREREQUISITES
#
sudo apt-get update || echo
sudo apt-get install unzip || echo
sudo curl https://releases.hashicorp.com/consul/1.0.2/consul_1.0.2_linux_amd64.zip -o /usr/local/bin/consul.zip || echo
unzip /usr/local/bin/consul.zip || echo
sudo chmod +x /usr/local/bin consul
sudo mkdir -p /opt/consul/data || echo

#
 # CONFIGURE CONSUL
#
sudo /usr/local/bin/consul agent -server -bootstrap-expect=3 -retry-join=10.0.1.6 -data-dir=/opt/consul/data
