#!/bin/bash
set -eu -o pipefail

# Install Certbot & dependencies as instructed for
# an nginx server running on Ubuntu 16.04, according
# to certbot's guidelines: https://certbot.eff.org/lets-encrypt/ubuntuxenial-nginx
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot python-certbot-nginx 