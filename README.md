# ambari-dev
Utility to setup ambari build environment for development purpose.

Pre-requisite:
- Working vagrant environment

Cluster deployment options:
1. Single Node HDFS cluster
2. Single Node HDFS and YARN cluster
3. Three node HDFS cluster
4. Three node HDFS and YARN cluster

Steps to execute:
- git clone git@github.com:u39kun/ambari-vagrant.git
- cd ambari-vagrant/centos6.4/
- git clone git@github.com:bhuvnesh2703/ambari-dev.git
- cd ambari-dev
- ./install_ambari_cluster.sh
- Login: http://c6401.ambari.apache.org:8080
