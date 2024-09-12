#!/bin/bash

# change the hostname to "master"
echo "Changing the hostname to master"
sudo hostnamectl set-hostname master
echo "master" | sudo tee /etc/hostname
echo "127.0.0.1 master" | sudo tee -a /etc/hosts
echo "Hostname changed successfully!"