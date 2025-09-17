#!/bin/bash
cd /var/www/html
sudo chown -R ubuntu:ubuntu /var/www/html
npm install
nohup npm start > /tmp/nodejs-app.log 2>&1 &
