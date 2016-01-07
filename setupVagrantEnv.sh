#!/bin/bash
git clone git@github.com:Pivotal-DataFabric/phd-ci.git

HOSTNAME_PREFIX='c640'
if [ -z "$1" ] ; then
  HOSTS=1
else
  HOSTS=$1
fi
for ((i=1; i<=HOSTS; i++));
  do
    vagrant_machine_name=`echo ${HOSTNAME_PREFIX}${i}`
    echo "Destroying $vagrant_machine_name"
    vagrant destroy -f $vagrant_machine_name
    echo "Creating $vagrant_machine_name"
    vagrant up $vagrant_machine_name
done

# Login to vagrant and setup the environment
vagrant ssh c6401 -c """

sudo yum -y install vim httpd python-devel python-pip tar
sudo service httpd start
sudo service iptables stop
sudo service ntpd start
sudo yum -y install epel-release
sudo sed -i \"s/mirrorlist=https/mirrorlist=http/\" /etc/yum.repos.d/epel.repo
pip install requests


pushd /vagrant/
# Changes quite often
sudo tar -xvzf AMBARI-109749232-Add-configs-to-metainfo-PHD-latest.tar.gz
sudo AMBARI-109749232-Add-configs-to-metainfo/setup_repo.sh

# Changes less frequently
sudo PHD-3.3.2.0/setup_repo.sh
sudo PHD-UTILS-1.1.0.20/setup_repo.sh
sudo pivotal-hdb-2.0.0.0/setup_repo.sh
sudo hawq-plugin-phd-2.0.0/setup_repo.sh

sudo yum -y install ambari-server hawq-plugin
sudo bash -c 'cat > /var/lib/ambari-server/resources/stacks/PHD/3.3/repos/repoinfo.xml << 'EOF'
<reposinfo>
  <os family=\"redhat6\">
    <repo>
      <baseurl>http://c6401.ambari.apache.org/PHD-3.3.2.0</baseurl>
      <repoid>PHD-3.3.2.0</repoid>
      <reponame>PHD-3.3.2.0</reponame>
    </repo>
    <repo>
      <baseurl>http://c6401.ambari.apache.org/PHD-UTILS-1.1.0.20</baseurl>
      <repoid>PHD-UTILS-1.1.0.20</repoid>
      <reponame>PHD-UTILS-1.1.0.20</reponame>
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
sudo ./phd-ci/ambari_cli/ambari bootstrap --deploy c6401.ambari.apache.org
sudo ./phd-ci/ambari_cli/ambari bootstrap --status --wait 1 OK
sudo ./phd-ci/ambari_cli/ambari blueprints --create single-node ./templates/single-node-blueprint.json
sudo ./phd-ci/ambari_cli/ambari clusters --create vagrant-phd-cluster ./templates/single-node-hostmapping-template.json
""" 
