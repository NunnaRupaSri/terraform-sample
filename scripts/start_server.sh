#!/bin/bash
cd /var/www/html
npm install
sudo npm start > /var/log/nodejs-app.log 2>&1 &
