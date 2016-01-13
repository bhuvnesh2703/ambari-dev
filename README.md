# ambari-dev
Utility to setup ambari cluster environment for development purpose on vagrant.

Pre-requisite:
- Working vagrant environment

KDC User/Password:
- KDC principal: admin/admin@AMBARI.APACHE.ORG 
- KDC password: admin

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
- Edit install_ambari_cluster.sh to update the below section with the links to download the respective tarballs for AMBARI, PHD, PHD-UTILS, HDB, HAWQ-PLUGIN
```
XXXX_TARBALL_DOWNLOAD_LINK="<tarball link>"
Example:
HDB_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HAWQ/stable/pivotal-hdb-latest-stable.tar.gz"
```
- ./install_ambari_cluster.sh
- Login: http://c6401.ambari.apache.org:8080

Note:
- AMBARI tarball will be downloaded everytime during script execution
- Feel free to optimize it as needed. (Just don't include many command line arguments)
