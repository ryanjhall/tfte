#!/bin/bash
#
 # SET VARIABLES
#
COUNT=$1
HOST=$2

#
 # INSTALL PREREQUISITES
#
sudo apt-get update
sudo apt-get install unzip
sudo curl https://releases.hashicorp.com/consul/1.0.2/consul_1.0.2_linux_amd64.zip -o /usr/local/bin/consul.zip
sudo unzip /usr/local/bin/consul
sudo chmod +x /usr/local/bin consul
sudo mkdir -p /opt/consul/data

#
 # CONFIGURE CONSUL
#
sudo /usr/local/bin/consul agent -server -bootstrap-expect=$1 -retry-join=$2 -data-dir=/opt/consul/data
