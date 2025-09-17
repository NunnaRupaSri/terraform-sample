#!/bin/bash
cd /var/www/html
npm install
nohup npm start > /var/log/nodejs-app.log 2>&1 &
echo $! > /var/run/nodejs-app.pid
