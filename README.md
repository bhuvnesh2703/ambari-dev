# ambari-dev
Utility to setup ambari build environment for development purpose.

**Currently works for deploying single node vagrant clusters**

Pre-requisite
- Vagrant

Steps to execute:
- git clone git@github.com:u39kun/ambari-vagrant.git
- cd ambari-vagrant/centos6.4/
- git clone git@github.com:bhuvnesh2703/ambari-dev.git
- cd ambari-dev
- ./setupVagrantEnv.sh

TODO:
- Allow 3 node cluster deployment
- Optimize
