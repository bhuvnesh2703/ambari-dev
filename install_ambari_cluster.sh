#!/bin/bash
###########################################################################################
# A simple bash script to install vagrant based ambari clusters
# Usage: ./install_ambari_cluster.sh
# When prompted enter the option to determine the type of cluster to be installed
###########################################################################################

###########################################################################################
# To test your ambari development build, update XXXXX_TARBALL_DOWNLOAD_LINK
# link to the path of the tarball from where it can be downloaded
###########################################################################################
AMBARI_TARBALL_DOWNLOAD_LINK="https://jenkins.eng.pivotal.io/jenkins/view/AMBR-OSS-BUILD/job/AMBR-OSS-BUILD-branch_2_2-HDP/lastSuccessfulBuild/artifact/target/AMBARI-branch-2.2-HDP-latest.tar.gz"
HDP_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HDP/HDP-2.3.4.0-centos6-rpm.tar.gz"
HDP_UTILS_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HDP/HDP-UTILS-1.1.0.20.tar.gz"
HDB_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HAWQ/stable/pivotal-hdb-latest-stable.tar.gz"
HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK="http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/PHD/latest/hawq-plugin-2.0.0-hdp-latest.tar.gz"
JDK_TARBALL_DOWNLOAD_LINK="http://public-repo-1.hortonworks.com/ARTIFACTS/jdk-8u60-linux-x64.tar.gz"
JCE_TARBALL_DOWNLOAD_LINK="http://public-repo-1.hortonworks.com/ARTIFACTS/jce_policy-8.zip"

###########################################################################################
# No change required below after you have updated the tarball path above
###########################################################################################
HOSTNAME_PREFIX='c640'

setup_tars() {
  pushd ../..
  for DOWNLOAD_LINK in $AMBARI_TARBALL_DOWNLOAD_LINK $HDP_TARBALL_DOWNLOAD_LINK $HDP_UTILS_TARBALL_DOWNLOAD_LINK $HDB_TARBALL_DOWNLOAD_LINK $HAWQ_PLUGIN_TARBALL_DOWNLOAD_LINK $JDK_TARBALL_DOWNLOAD_LINK $JCE_TARBALL_DOWNLOAD_LINK
  do
    TAR_NAME=`basename ${DOWNLOAD_LINK}`
    echo $TAR_NAME
    if [[ ${TAR_NAME} == AMBARI* ]]; then 
      rm -f ${TAR_NAME}
    fi
    if [ ! -f ${TAR_NAME} ] ; then
      curl -O ${DOWNLOAD_LINK}
    fi

    FOLDER_NAME=$(tar -tf ${TAR_NAME} | head -1 | sed "s/.$//")
    if [[ ${FOLDER_NAME} == AMBARI* ]]; then 
      rm -rf ${FOLDER_NAME}
    fi
    if [[ (! -d ${FOLDER_NAME}) && (${TAR_NAME} != j*) ]]; then
      tar -xvzf ${TAR_NAME}
    fi

    if [[ $FOLDER_NAME == HDP/centos6* ]] ; then
      export HDP_FOLDERNAME=$FOLDER_NAME
    fi
    if [[ $FOLDER_NAME == HDP-UTILS* ]]; then
      export HDP_UTILS_FOLDERNAME=$FOLDER_NAME
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
    if [[ $FOLDER_NAME == jdk* ]]; then
      export JDK_TARNAME=$TAR_NAME
    fi
    if [[ $FOLDER_NAME == UnlimitedJCE* ]]; then
      export JCE_TARNAME=$TAR_NAME
    fi
  done
  popd
}

setup_host() {
    echo "Creating ${HOST} and taking Snapshot..."
    vagrant up ${HOST}
    vagrant ssh ${HOST} -c """
            sudo yum -y install vim httpd
        """
    if [ $HOST == c6401 ]; then
    vagrant ssh ${HOST} -c """
            sudo yum -y install postgresql-server
        """
    fi
    vagrant snapshot take ${HOST} ${HOST}
}

setup_vagrant() {
  echo "Checking vagrant-vbox-snapshot plugin..."
  if [[ ! $(vagrant plugin list | grep vagrant-vbox-snapshot)  ]]; then
    echo "please install plugin using ..."
    echo "********************************************"
    echo "vagrant plugin install vagrant-vbox-snapshot"
    echo "*********************************************"
    exit 1
  fi

  if [ $1 == 1 ]; then
    for ((i=2; i<=3; i++)); do
      HOST=${HOSTNAME_PREFIX}${i}
      if [[ $(vagrant status ${HOST} | grep "running") ]]; then
        echo "Suspending ${HOST}"
        vagrant suspend ${HOST}
      fi
    done
  fi

  for ((i=1; i<=$1; i++)); do
    HOST=${HOSTNAME_PREFIX}${i}
    if [[ $(vagrant status ${HOST} | egrep "saved|poweroff") ]]; then
      echo "Resuming saved state of ${HOST}"
      vagrant up ${HOST}
    fi
    echo "Checking .... ${HOST}"
    vagrant ssh ${HOST} -c """ echo '${HOST} is up & running..' """
    if [ $? -eq 0 ]; then
      echo "Retrieving snapshot for ${HOST}...."
      vagrant snapshot back ${HOST}
      if [ $? -ne 0 ]; then
        echo "Snapshot not available."
        echo "Destroying ${HOST}..."
        vagrant destroy -f ${HOST}
        setup_host
      fi
    else
      vagrant destroy -f ${HOST}
      setup_host
    fi
  done
}

setup_ambari_server() {
  # Login to vagrant and setup the environment
  vagrant ssh c6401 -c """
    sudo yum -y install vim httpd rsync
    sudo service httpd start
    sudo service iptables stop
    sudo service ntpd start

    pushd /vagrant/
    cp ${AMBARI_FOLDERNAME}/setup_repo.sh ${HDP_FOLDERNAME}/
    sudo ${AMBARI_FOLDERNAME}/setup_repo.sh
    sudo ${HDP_FOLDERNAME}/setup_repo.sh
    sudo ${HDP_UTILS_FOLDERNAME}/setup_repo.sh
    sudo ${HDB_FOLDERNAME}/setup_repo.sh
    sudo ${HAWQ_PLUGIN_FOLDERNAME}/setup_repo.sh
    popd

    sudo yum -y install ambari-server hawq-plugin ambari-agent
    sudo ambari-agent start
    sudo sed -i 's/hostname=localhost/hostname=c6401.ambari.apache.org/' /etc/ambari-agent/conf/ambari-agent.ini

    sudo bash -c 'cat > /var/lib/ambari-server/resources/stacks/HDP/2.3/repos/repoinfo.xml << 'EOF'
    <reposinfo>
      <os family=\"redhat6\">
        <repo>
          <baseurl>http://c6401.ambari.apache.org/2.3.4.0</baseurl>
          <repoid>HDP-2.3</repoid>
          <reponame>HDP</reponame>
        </repo>
        <repo>
          <baseurl>http://c6401.ambari.apache.org/HDP-UTILS-1.1.0.20</baseurl>
          <repoid>HDP-UTILS-1.1.0.20</repoid>
          <reponame>HDP-UTILS</reponame>
        </repo>
        <repo>
          <baseurl>http://c6401.ambari.apache.org/PIVOTAL-HDB</baseurl>
          <repoid>PIVOTAL-HDB</repoid>
          <reponame>PIVOTAL-HDB</reponame>
        </repo>
      </os>
    </reposinfo>
EOF'
    sudo cp /vagrant/$JDK_TARNAME /var/lib/ambari-server/resources
    sudo cp /vagrant/$JCE_TARNAME /var/lib/ambari-server/resources
    sudo ambari-server setup -s && sudo ambari-server start
    sleep 15
""" 
}

read_input_options() {
  default_user_nodes_input="1"
  read -p """  Nodes required
          1: Single Node cluster
          2: Three Node cluster
  Enter option 1 or 2 [${default_user_nodes_input}]: """ user_nodes_input
  user_nodes_input="${user_nodes_input:-$default_user_nodes_input}"
  if  [ ! ${user_nodes_input} -eq "1" ] && [ ! ${user_nodes_input} -eq "2" ] ;  then
    echo "Invalid options chosen for nodes required, please choose either option 1 or 2"
    exit 1
  fi

  default_user_service_input="2"
  read -p """  Services required
          1: Ambari only
          2: HDFS and YARN without HAWQ
          3: HDFS and YARN with HAWQ/PXF
  Enter option 1, 2 or 3 [${default_user_service_input}]: """ user_service_input
  user_service_input="${user_service_input:-$default_user_service_input}"

  if  [ ! ${user_service_input} -eq "1" ] && [ ! ${user_service_input} -eq "2" ] && [ ! ${user_service_input} -eq "3" ] ;  then
    echo "Invalid options chosen for services required, please choose either option 1, 2 or 3"
    exit 1
  fi

  default_ambari_tar_input=$AMBARI_TARBALL_DOWNLOAD_LINK
  read -p """  Ambari TAR URL ? [$default_ambari_tar_input]:
  """ ambari_tar_input
  AMBARI_TARBALL_DOWNLOAD_LINK="${ambari_tar_input:-$default_ambari_tar_input}"

  if [ ${user_nodes_input} -eq "1" ] ; then
    NODES=1
    if  [ ${user_service_input} -eq "2" ]; then
      BLUEPRINT_NAME='one-node-hdfs-blueprint'
      HOSTMAPPING_FILENAME='one-node-hdfs-hostmapping'
    elif [ ${user_service_input} -eq "3" ]; then
      BLUEPRINT_NAME='one-node-hdfs-hawq-blueprint'
      HOSTMAPPING_FILENAME='one-node-hdfs-hawq-hostmapping'
    fi
  elif [ ${user_nodes_input} -eq "2" ]; then
    NODES=3
    if  [ ${user_service_input} -eq "2" ]; then
      BLUEPRINT_NAME='three-node-hdfs-blueprint'
      HOSTMAPPING_FILENAME='three-node-hdfs-hostmapping'
    elif [ ${user_service_input} -eq "3" ]; then
      BLUEPRINT_NAME='three-node-hdfs-hawq-blueprint'
      HOSTMAPPING_FILENAME='three-node-hdfs-hawq-hostmapping'
    fi
  else
    echo "Invalid option chosen for nodes required, please choose either option 1 or 2"
    exit 1
  fi
}

bootstrap() {
  curl -i -uadmin:admin -H 'X-Requested-By: ambari' -H 'Content-Type: application/json' -X POST -d@templates/bootstrap.json http://c6401.ambari.apache.org:8080/api/v1/bootstrap
  echo
  sleep 15
}

create_cluster() {
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/blueprints/blueprint -d @${SCRIPT_LOCATION}/templates/$1
  curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/clusters/hdp -d @${SCRIPT_LOCATION}/templates/$2
  echo
}

enable_security() {
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

if [ "$1" == "--secure" ]; then
  echo Creating a cluster with security turned ON
  export SET_SECURITY_FLG="Y"
else
  echo Please use "install_ambari_cluster.sh" --secure to create a secure cluster
fi

SCRIPT_RELATIVE_PATH=`dirname "$0"`
CURRENT_DIR=`echo $PWD`
if [ $SCRIPT_RELATIVE_PATH == "." ]; then
  export SCRIPT_LOCATION=$CURRENT_DIR
else
  export SCRIPT_LOCATION=$CURRENT_DIR/$SCRIPT_RELATIVE_PATH
fi

read_input_options
setup_tars
setup_vagrant ${NODES}
if [ "$SET_SECURITY_FLG" == "Y" ] ; then
  enable_security
fi
setup_ambari_server
if [ ${user_nodes_input} -eq "2" ]; then
  bootstrap
fi
if [ ! ${user_service_input} -eq "1" ]; then
  create_cluster ${BLUEPRINT_NAME}.json ${HOSTMAPPING_FILENAME}.json
  echo "Please verify cluster creation progress..."
fi
echo "Ambari server available at http://c6401.ambari.apache.org:8080/"
