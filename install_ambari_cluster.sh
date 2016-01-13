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
AMBARI_TARBALL_DOWNLOAD_LINK="https://jenkins.eng.pivotal.io/jenkins/view/AMBR-OSS-BUILD/job/AMBR-OSS-BUILD-BRANCH-1/lastSuccessfulBuild/artifact/target/AMBARI-111177100-blueprint-deploy-branch-2.2-PHD-latest.tar.gz"
PHD_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-3.3.2.0-2950-centos6.tar.gz" 
PHD_UTILS_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-UTILS-1.1.0.20-centos6.tar.gz"
HDB_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HAWQ/stable/pivotal-hdb-latest-stable.tar.gz"
HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/PHD/latest/hawq-plugin-2.0.0-phd-latest.tar.gz"

###########################################################################################
# No change required below after you have updated the tarball path above
###########################################################################################
HOSTNAME_PREFIX='c640'

setup_tars() {
  pushd ../
  for DOWNLOAD_LINK in $AMBARI_TARBALL_DOWNLOAD_LINK $PHD_TARBALL_DOWNLOAD_LINK $PHD_UTILS_TARBALL_DOWNLOAD_LINK $HDB_TARBALL_DOWNLOAD_LINK $HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK
  do
    TAR_NAME=`basename ${DOWNLOAD_LINK}`
    if [[ ${TAR_NAME} == AMBARI* ]]; then 
      rm -f ${TAR_NAME}
    fi
    if [ ! -f ${TAR_NAME} ] ; then
      wget ${DOWNLOAD_LINK}
    fi

    FOLDER_NAME=$(tar -tf ${TAR_NAME} | head -1 | tr -d "/")
    if [[ ${FOLDER_NAME} == AMBARI* ]]; then 
      rm -rf ${FOLDER_NAME}
    fi
    if [ ! -d ${FOLDER_NAME} ]; then
      tar -xvzf ${TAR_NAME}
    fi

    if [[ $FOLDER_NAME == PHD-3* ]] ; then 
      export PHD_FOLDERNAME=$FOLDER_NAME
    fi
    if [[ $FOLDER_NAME == PHD-UTILS* ]]; then
      export PHD_UTILS_FOLDERNAME=$FOLDER_NAME
    fi
    if [[ $FOLDER_NAME == AMBARI* ]]; then
      export AMBARI_FOLDERNAME=$FOLDER_NAME
    fi
    if [[ $FOLDER_NAME == hawq-plugin* ]]; then
      export HAWQ_PLUGIN_FOLDERNAME=$FOLDER_NAME
    fi
    if [[ $FOLDER_NAME == pivotal-hdb* ]]; then
      export HDB_FOLDERNAME=$FOLDER_NAME
    fi
  done
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
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/blueprints/blueprint -d @${SCRIPT_LOCATION}/templates/$1
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/clusters/phd -d @${SCRIPT_LOCATION}/templates/$2
}

set_kdc() {
  vagrant ssh c6401 -c """
    set -e
    HOSTNAME="c6401.ambari.apache.org"
    sudo yum install -y krb5-server krb5-workstation krb5-libs
    sudo sed -i \"s/default_realm = EXAMPLE.COM/default_realm = AMBARI.APACHE.ORG/\" /etc/krb5.conf
    sudo sed -i \"s/EXAMPLE.COM = {/AMBARI.APACHE.ORG = {/\" /etc/krb5.conf
    sudo sed -i \"s/kdc = kerberos.example.com/kdc = ${HOSTNAME}/\" /etc/krb5.conf
    sudo sed -i \"s/admin_server = kerberos.example.com/admin_server = ${HOSTNAME}/\" /etc/krb5.conf
    sudo sed -i \"/\.example.com = EXAMPLE.COM/d\" /etc/krb5.conf
    sudo sed -i \"s/example.com = EXAMPLE.COM/${HOSTNAME} = AMBARI.APACHE.ORG/\" /etc/krb5.conf
    echo \"Please be patient, this step (kdb5_util create -s) takes long. Have not debugged if there is any problem, but it works.\"
    printf 'admin\\nadmin\\n' | sudo kdb5_util create -s
    sudo sed -i \"s/EXAMPLE.COM/AMBARI.APACHE.ORG/\" /var/kerberos/krb5kdc/kadm5.acl
    sudo kadmin.local -q \"addprinc -pw admin admin/admin@AMBARI.APACHE.ORG\"
    sudo service kadmin start
    sudo service krb5kdc start
    echo \"Kerberos admin principal: admin/admin@AMBARI.APACHE.ORG\"
    echo \"Kerberos admin password: admin\"
  """
}
# Execution starts here
if [ "$1" == "--cleanup" ]; then
  vagrant destroy -f c6401
  vagrant destroy -f c6402
  vagrant destroy -f c6403
  exit 1
fi

SCRIPT_RELATIVE_PATH=`dirname "$0"`
CURRENT_DIR=`echo $PWD`
if [ $SCRIPT_RELATIVE_PATH == "." ]; then
  export SCRIPT_LOCATION=$CURRENT_DIR
else
  export SCRIPT_LOCATION=$CURRENT_DIR/$SCRIPT_RELATIVE_PATH
fi

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

SET_SECURITY_FLG='N'
echo """Do you need to setup kdc on ambari host ? Yy/Nn"""
read user_security_input
case "$user_security_input" in
 y|Y) export SET_SECURITY_FLG='Y';;
 n|N) export SET_SECURITY_FLG='N';;
 *) echo "Please enter a valid option. Yy|Nn"
    exit 1;;
esac

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
if [ $SET_SECURITY_FLG = 'Y' ] ; then 
  set_kdc
fi
setup_ambari_server
if [ ${user_nodes_input} -eq "2" ]; then
  bootstrap
fi
create_cluster ${BLUEPRINT_NAME}.json ${HOSTMAPPING_FILENAME}.json
echo "Please verify cluster creation progress at: http://c6401.ambari.apache.org"
