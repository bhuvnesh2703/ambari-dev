# ambari-dev
Utility to setup ambari build environment for development purpose.

Pre-requisite:
- Working vagrant environment

Cluster deployment options:
- Single Node HDFS cluster
- Single Node HDFS and YARN cluster
- Three node HDFS cluster
- Three node HDFS and YARN cluster

Steps to execute:
- git clone git@github.com:u39kun/ambari-vagrant.git
- cd ambari-vagrant/centos6.4/
- git clone git@github.com:bhuvnesh2703/ambari-dev.git
- cd ambari-dev
- ./install_ambari_cluster.sh
- Login: http://c6401.ambari.apache.org:8080
