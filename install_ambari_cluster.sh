#!/bin/bash
set -e
###########################################################################################
# A simple bash script to install vagrant based ambari clusters
# Usage: ./install_ambari_cluster.sh
# When prompted enter the option to determine the type of cluster to be installed
###########################################################################################

###########################################################################################
# To test your ambari development build, update XXXXX_TARBALL_DOWNLOAD_LINK
# link to the path of the tarball from where it can be downloaded
###########################################################################################
AMBARI_TARBALL_DOWNLOAD_LINK="https://jenkins.eng.pivotal.io/jenkins/view/AMBR-OSS-BUILD/job/AMBR-OSS-BUILD-trunk/lastSuccessfulBuild/artifact/target/AMBARI-trunk-PHD-latest.tar.gz"
PHD_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-3.3.2.0-2950-centos6.tar.gz" 
PHD_UTILS_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-UTILS-1.1.0.20-centos6.tar.gz"
HDB_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HAWQ/stable/pivotal-hdb-latest-stable.tar.gz"
HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/PHD/latest/hawq-plugin-2.0.0-phd-latest.tar.gz"


###########################################################################################
# No change required below after you have updated the tarball path above
###########################################################################################
PHD_TARBALL=`basename ${PHD_TARBALL_DOWNLOAD_LINK}`
PHD_UTILS_TARBALL=`basename ${PHD_UTILS_TARBALL_DOWNLOAD_LINK}` 
HDB_TARBALL=`basename ${HDB_TARBALL_DOWNLOAD_LINK}`
HAWQ_PLUGIN_TARBALL=`basename ${HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK}`
AMBARI_TARBALL=`basename ${AMBARI_TARBALL_DOWNLOAD_LINK}` 

HOSTNAME_PREFIX='c640'

setup_tars() {
  pushd ../
  if [ ! -f ${AMBARI_TARBALL} ] ; then 
    wget ${AMBARI_TARBALL_DOWNLOAD_LINK}
  fi
  export AMBARI_FOLDERNAME=$(tar -tf ${AMBARI_TARBALL} | head -1 | tr -d "/")
  if [ ! -d ${AMBARI_FOLDERNAME} ] ; then
    tar -xzf ${AMBARI_TARBALL}
  fi

  if [ ! -f ${PHD_TARBALL} ] ; then 
    wget ${PHD_TARBALL_DOWNLOAD_LINK}
  fi
  export PHD_FOLDERNAME=$(tar -tf ${PHD_TARBALL} | head -1 | tr -d "/")
  if [ ! -d ${PHD_FOLDERNAME} ] ; then
    tar -xzf ${PHD_TARBALL}
  fi

  if [ ! -f ${PHD_UTILS_TARBALL} ] ; then 
    wget ${PHD_UTILS_TARBALL_DOWNLOAD_LINK}
  fi
  export PHD_UTILS_FOLDERNAME=$(tar -tf ${PHD_UTILS_TARBALL} | head -1 | tr -d "/")
  if [ ! -d ${PHD_UTILS_FOLDERNAME} ] ; then
    tar -xzf ${PHD_UTILS_TARBALL}
  fi 

  if [ ! -f ${HDB_TARBALL} ] ; then 
    wget ${HDB_TARBALL_DOWNLOAD_LINK}
  fi
  export HDB_FOLDERNAME=$(tar -tf ${HDB_TARBALL} | head -1 | tr -d "/")
  if [ ! -d ${HDB_FOLDERNAME} ] ; then
    tar -xzf ${HDB_TARBALL}
  fi    

  if [ ! -f ${HAWQ_PLUGIN_TARBALL} ] ; then 
    wget ${HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK}
  fi
  export HAWQ_PLUGIN_FOLDERNAME=$(tar -tf ${HAWQ_PLUGIN_TARBALL} | head -1 | tr -d "/")
  if [ ! -d ${HAWQ_PLUGIN_FOLDERNAME} ] ; then
    tar -xzf ${HAWQ_PLUGIN_TARBALL}
  fi
  popd
}


setup_vagrant() {
  for ((i=1; i<=$1; i++)); do
    HOST=${HOSTNAME_PREFIX}${i}
    echo "Destroying Vagrant machine: ${HOST}"
    vagrant destroy -f ${HOST}
    echo "Creating Vagrant machine: ${HOST}"
    vagrant up ${HOST}
  done
}

setup_ambari_server() {
  # Login to vagrant and setup the environment
  vagrant ssh c6401 -c """
    sudo yum -y install vim httpd
    sudo service httpd start
    sudo service iptables stop
    sudo service ntpd start

    pushd /vagrant/
    sudo ${AMBARI_FOLDERNAME}/setup_repo.sh
    sudo ${PHD_FOLDERNAME}/setup_repo.sh
    sudo ${PHD_UTILS_FOLDERNAME}/setup_repo.sh
    sudo ${HDB_FOLDERNAME}/setup_repo.sh
    sudo ${HAWQ_PLUGIN_FOLDERNAME}/setup_repo.sh
    popd

    sudo yum -y install ambari-server hawq-plugin ambari-agent
    sudo ambari-agent start
    sudo sed -i 's/hostname=localhost/hostname=c6401.ambari.apache.org/' /etc/ambari-agent/conf/ambari-agent.ini

    sudo bash -c 'cat > /var/lib/ambari-server/resources/stacks/PHD/3.3/repos/repoinfo.xml << 'EOF'
    <reposinfo>
      <os family=\"redhat6\">
        <repo>
          <baseurl>http://c6401.ambari.apache.org/${PHD_FOLDERNAME}</baseurl>
          <repoid>${PHD_FOLDERNAME}</repoid>
          <reponame>${PHD_FOLDERNAME}</reponame>
        </repo>
        <repo>
          <baseurl>http://c6401.ambari.apache.org/${PHD_UTILS_FOLDERNAME}</baseurl>
          <repoid>${PHD_UTILS_FOLDERNAME}</repoid>
          <reponame>${PHD_UTILS_FOLDERNAME}</reponame>
        </repo>
        <repo>
          <baseurl>http://c6401.ambari.apache.org/PIVOTAL-HDB</baseurl>
          <repoid>PIVOTAL-HDB</repoid>
          <reponame>PIVOTAL-HDB</reponame>
        </repo>
      </os>
    </reposinfo>
EOF'
    sudo ambari-server setup -s && sudo ambari-server start
    sleep 30
""" 
}

bootstrap() {
  curl -i -uadmin:admin -H 'X-Requested-By: ambari' -H 'Content-Type: application/json' -X POST -d@templates/bootstrap.json http://c6401.ambari.apache.org:8080/api/v1/bootstrap
  sleep 15
}

create_cluster() {
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/blueprints/blueprint -d @templates/$1
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/clusters/phd -d @templates/$2
}

echo """Services required, enter option 1 or 2:
        1: HDFS Service
        2: HDFS and YARN Service"""
read user_service_input
if  [ ! ${user_service_input} -eq "1" ] && [ ! ${user_service_input} -eq "2" ] ;  then
  echo "Invalid options chosen for services required, please choose either option 1 or 2"
  exit 1
fi

echo """Nodes required, enter option 1 or 2:
        1: Single Node cluster
        2: Three Node cluster"""

read user_nodes_input

if [ ${user_nodes_input} -eq "1" ] ; then
  NODES=1
  if  [ ${user_service_input} -eq "1" ]; then
    BLUEPRINT_NAME='one-node-hdfs-blueprint'
    HOSTMAPPING_FILENAME='one-node-hdfs-hostmapping'
  else
    BLUEPRINT_NAME='one-node-hdfs-yarn-blueprint'
    HOSTMAPPING_FILENAME='one-node-hdfs-yarn-hostmapping'
  fi
elif [ ${user_nodes_input} -eq "2" ]; then
  NODES=3
  if  [ ${user_service_input} -eq "1" ]; then
    BLUEPRINT_NAME='three-node-hdfs-blueprint'
    HOSTMAPPING_FILENAME='three-node-hdfs-hostmapping'
  else
    BLUEPRINT_NAME='three-node-hdfs-yarn-blueprint'
    HOSTMAPPING_FILENAME='three-node-hdfs-yarn-hostmapping'
  fi
else
  echo "Invalid option chosen for nodes required, please choose either option 1 or 2"
  exit 1
fi

setup_tars
setup_vagrant ${NODES}
setup_ambari_server
if [ ${user_nodes_input} -eq "2" ]; then
  bootstrap
fi
create_cluster ${BLUEPRINT_NAME}.json ${HOSTMAPPING_FILENAME}.json
echo "Please verify cluster creation progress at: http://c6401.ambari.apache.org"
