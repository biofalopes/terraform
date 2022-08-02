#!/bin/bash

sudo apt -y update &&
sudo apt -y install \
    nginx &&

echo "$(curl http://169.254.169.254/latest/meta-data/local-ipv4)" > /usr/share/nginx/html/index.html
sudo systemctl enable nginx
sudo systemctl start nginx