#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Install ansible
sudo apt-get update
sudo apt-get install -y python-pip ansible
sudo pip install docker

ansible --version
