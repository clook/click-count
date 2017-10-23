#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Install ansible
sudo apt-get update
sudo apt-get install -y ansible python-pip
sudo pip install docker-py

ansible --version
