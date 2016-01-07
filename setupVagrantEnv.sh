#!/bin/bash
HOSTNAME_PREFIX='c640'

function setup_server() {
  # Login to vagrant and setup the environment
  vagrant ssh c6401 -c """
    sudo yum -y install vim httpd
    sudo service httpd start
    sudo service iptables stop
    sudo service ntpd start

    pushd /vagrant/
    # Changes quite often
    sudo tar -xvzf AMBARI-trunk-PHD-latest.tar.gz
    sudo AMBARI-trunk/setup_repo.sh

    # Changes less frequently
    sudo PHD-3.3.2.0/setup_repo.sh
    sudo PHD-UTILS-1.1.0.20/setup_repo.sh
    sudo pivotal-hdb-2.0.0.0/setup_repo.sh
    sudo hawq-plugin-phd-2.0.0/setup_repo.sh

    sudo yum -y install ambari-server hawq-plugin ambari-agent
    sudo ambari-agent start
    sudo sed -i 's/hostname=localhost/hostname=c6401.ambari.apache.org/' /etc/ambari-agent/conf/ambari-agent.ini

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
    sleep 10
""" 
}

function setup_agents() {
  vagrant ssh c6401 -c """
      curl -i -uadmin:admin -H 'X-Requested-By: ambari' -H 'Content-Type: application/json' -X POST -d'{
       \"verbose\":true,
       \"sshKey\":\"-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzI
w+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoP
kcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2
hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NO
Td0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcW
yLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQIBIwKCAQEA4iqWPJXtzZA68mKd
ELs4jJsdyky+ewdZeNds5tjcnHU5zUYE25K+ffJED9qUWICcLZDc81TGWjHyAqD1
Bw7XpgUwFgeUJwUlzQurAv+/ySnxiwuaGJfhFM1CaQHzfXphgVml+fZUvnJUTvzf
TK2Lg6EdbUE9TarUlBf/xPfuEhMSlIE5keb/Zz3/LUlRg8yDqz5w+QWVJ4utnKnK
iqwZN0mwpwU7YSyJhlT4YV1F3n4YjLswM5wJs2oqm0jssQu/BT0tyEXNDYBLEF4A
sClaWuSJ2kjq7KhrrYXzagqhnSei9ODYFShJu8UWVec3Ihb5ZXlzO6vdNQ1J9Xsf
4m+2ywKBgQD6qFxx/Rv9CNN96l/4rb14HKirC2o/orApiHmHDsURs5rUKDx0f9iP
cXN7S1uePXuJRK/5hsubaOCx3Owd2u9gD6Oq0CsMkE4CUSiJcYrMANtx54cGH7Rk
EjFZxK8xAv1ldELEyxrFqkbE4BKd8QOt414qjvTGyAK+OLD3M2QdCQKBgQDtx8pN
CAxR7yhHbIWT1AH66+XWN8bXq7l3RO/ukeaci98JfkbkxURZhtxV/HHuvUhnPLdX
3TwygPBYZFNo4pzVEhzWoTtnEtrFueKxyc3+LjZpuo+mBlQ6ORtfgkr9gBVphXZG
YEzkCD3lVdl8L4cw9BVpKrJCs1c5taGjDgdInQKBgHm/fVvv96bJxc9x1tffXAcj
3OVdUN0UgXNCSaf/3A/phbeBQe9xS+3mpc4r6qvx+iy69mNBeNZ0xOitIjpjBo2+
dBEjSBwLk5q5tJqHmy/jKMJL4n9ROlx93XS+njxgibTvU6Fp9w+NOFD/HvxB3Tcz
6+jJF85D5BNAG3DBMKBjAoGBAOAxZvgsKN+JuENXsST7F89Tck2iTcQIT8g5rwWC
P9Vt74yboe2kDT531w8+egz7nAmRBKNM751U/95P9t88EDacDI/Z2OwnuFQHCPDF
llYOUI+SpLJ6/vURRbHSnnn8a/XG+nzedGH5JGqEJNQsz+xT2axM0/W/CRknmGaJ
kda/AoGANWrLCz708y7VYgAtW2Uf1DPOIYMdvo6fxIB5i9ZfISgcJ/bbCUkFrhoH
+vq/5CIWxCPp0f85R4qxxQ5ihxJ0YDQT9Jpx4TMss4PSavPaBH3RXow5Ohe+bYoQ
NE5OgEXk2wVfZczCZpigBKbKZHNYcelXtTt/nP3rsCuGcM4h53s=
-----END RSA PRIVATE KEY-----\",
       \"hosts\":[
          \"c6401.ambari.apache.org\",
          \"c6402.ambari.apache.org\",
          \"c6403.ambari.apache.org\"
       ],
       \"user\":\"vagrant\"
      }' http://c6401.ambari.apche.org:8080/api/v1/bootstrap
   """
}

function create_cluster() {
  vagrant ssh c6401 -c """
  sudo curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/blueprints/${BLUEPRINT_NAME} -d @/vagrant/ambari-dev/templates/${BLUEPRINT_FILENAME}
  sudo curl -u admin:admin -i -H 'X-Requested-By: ambari' -X POST http://c6401.ambari.apache.org:8080/api/v1/clusters/phd -d @/vagrant/ambari-dev/templates/${HOSTMAPPING_FILENAME}
  """
}

function setup_tars() {
if [ ! -d "../PHD-3.3.2.0" ] ; then
  wget http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-3.3.2.0-2950-centos6.tar.gz
  tar -xvzf PHD-3.3.2.0-2950-centos6.tar.gz
fi

if [ ! -d "../PHD-UTILS-1.1.0.20" ] ; then
  wget http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/hortonworks/certified/PHD-UTILS-1.1.0.20-centos6.tar.gz
  tar -xvzf PHD-UTILS-1.1.0.20-centos6.tar.gz
fi 

if [ ! -d "../pivotal-hdb-2.0.0.0" ] ; then
  wget http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/HAWQ/stable/pivotal-hdb-latest-stable.tar.gz
  tar -xvzf pivotal-hdb-latest-stable.tar.gz
fi    

if [ ! -d "../hawq-plugin-phd-2.0.0" ] ; then
  wget http://internal-dist-elb-877805753.us-west-2.elb.amazonaws.com/dist/PHD/latest/hawq-plugin-2.0.0-phd-latest.tar.gz
  tar -xvzf hawq-plugin-2.0.0-phd-latest.tar.gz
fi
}

if [ -z "$1" ] ; then
  HOSTS=1
  echo """Cluster required:
        Press 1 for HDFS only
        Press 2 for HDFS and YARN"""
  read user_input
  if [ $user_input == "1" ] ; then
    BLUEPRINT_NAME='single-node-hdfs-only-blueprint'
    HOSTMAPPING_FILENAME='single-node-hdfs-only-hostmapping-template.json'
  elif [ $user_input == "2" ] ; then
    BLUEPRINT_NAME='single-node-blueprint'
    HOSTMAPPING_FILENAME='single-node-hostmapping-template.json'
  fi
  BLUEPRINT_FILENAME=${BLUEPRINT_NAME}.json
else
  echo "No parameters accepted"
  HOSTS=3
  exit 1
  # TODO: Ensure that 3 node cluster works depending on command line input params
  BLUEPRINT_NAME='three-node-blueprint'
  BLUEPRINT_FILENAME=${BLUEPRINT_NAME}.json
  HOSTMAPPING_FILENAME='three-node-hostmapping-template.json'
fi

setup_tars

for ((i=1; i<=HOSTS; i++));
  do
    vagrant_machine_name=`echo ${HOSTNAME_PREFIX}${i}`
    echo "Destroying $vagrant_machine_name"
    vagrant destroy -f $vagrant_machine_name
    echo "Creating $vagrant_machine_name"
    vagrant up $vagrant_machine_name
done
setup_server
if [ ${HOSTS} -gt "1" ] ; then 
  setup_agents
fi
create_cluster
