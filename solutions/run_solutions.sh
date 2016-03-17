#!/usr/bin/env bash

BOX="hashicorp/precise64"
SOLUTIONS=solutions

log(){
  echo "`date` ${1}" >> output.log
}

load_web(){
ENTITY=web
mkdir $SOLUTIONS/$ENTITY
FILE="$SOLUTIONS/$ENTITY/Vagrantfile"

/bin/cat <<EOM >$FILE
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end
  config.vm.hostname = "web"
  config.vm.box = "${BOX}"
  config.vm.network "private_network", ip: "192.168.99.101"
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y nginx ufw
    sudo service nginx restart
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80
    sudo ufw --force enable
  SHELL
end
EOM

cd $SOLUTIONS/$ENTITY
vagrant up
log " - $ENTITY's up"
cd ../..
}

load_app(){
ENTITY=app
mkdir $SOLUTIONS/$ENTITY
FILE="$SOLUTIONS/$ENTITY/Vagrantfile"

/bin/cat <<EOM >$FILE
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end
  config.vm.hostname = "app"
  config.vm.box = "${BOX}"
  config.vm.network "private_network", ip: "192.168.99.102"
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install curl ufw -y
    curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -
    sudo apt-get install -y nodejs ufw
    npm install -g express-generator
    express hooq
    cd hooq
    npm install
    npm start &
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 3000
    sudo ufw --force enable
  SHELL
end
EOM

cd $SOLUTIONS/$ENTITY
vagrant up
log " - $ENTITY's up"
cd ../..
}

load_db(){
ENTITY=db
mkdir $SOLUTIONS/$ENTITY
FILE="$SOLUTIONS/$ENTITY/Vagrantfile"

/bin/cat <<EOM >$FILE
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end
  config.vm.hostname = "db"
  config.vm.box = "${BOX}"
  config.vm.network "private_network", ip: "192.168.99.104"
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y postgresql ufw
    sudo echo "listen_addresses = '192.168.99.104'" >> /etc/postgresql/9.1/main/postgresql.conf
    sudo echo "host  all  all 0.0.0.0/0 trust" >> /etc/postgresql/9.1/main/pg_hba.conf
    sudo service postgresql restart
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 5432
    sudo ufw --force enable
  SHELL
end
EOM

cd $SOLUTIONS/$ENTITY
vagrant up
log " - $ENTITY's up"
cd ../..
}

load_cache(){
ENTITY=cache
mkdir $SOLUTIONS/$ENTITY
FILE="$SOLUTIONS/$ENTITY/Vagrantfile"

/bin/cat <<EOM >$FILE
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end
  config.vm.hostname = "cache"
  config.vm.box = "${BOX}"
  config.vm.network "private_network", ip: "192.168.99.103"
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y ufw make
    wget http://download.redis.io/releases/redis-3.0.7.tar.gz
    tar xzvf redis-3.0.7.tar.gz
    cd redis-3.0.7
    make
    sed -i -- 's/127.0.0.1/192.168.99.103/g' redis.conf
    sed -i -- 's/daemonize no/daemonize yes/g' redis.conf
    src/redis-server redis.conf &
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 6379
    ufw --force enable
  SHELL
end
EOM

cd $SOLUTIONS/$ENTITY
vagrant up
log " - $ENTITY's up"
cd ../..
}

if [[ "" == $1 ]];then
  echo "I recommend to use local box for faster process and to safe bandwidth."
  read -p "use \"$ sh solutions/run_solutions.sh [your_box]. wanna try?\" (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]];then
   exit 1
  fi
else
  BOX=$1
fi

echo 'Running..'
log 'start'
log "using $BOX box"

log 'loading webserver'
load_web

log 'loading application'
load_app

log 'loading database'
load_db

log 'loading cache'
load_cache

log 'preparing test unit'

npm install
npm install mocha -g
npm run init

log 'moment of truth!'
npm test

echo 'done!'
echo 'boyke@mas-mas.it'
log 'done'
