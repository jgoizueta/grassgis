# -*- mode: ruby -*-
# vi: set ft=ruby :

# GRASS 7 environment on Ubuntu for tests
Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty32"

  config.vm.provision "shell", inline: <<-SHELL
    sudo add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
    sudo add-apt-repository -y ppa:grass/grass-stable
    sudo apt-get update -y
    sudo apt-get install -y grass7
    sudo apt-get install -y grass7-dev
    sudo apt-get install -y build-essential
    sudo apt-get install -y ruby-dev
    sudo apt-get install -y libsqlite3-dev
    sudo gem install bundler
  SHELL
end
