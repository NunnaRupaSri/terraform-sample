#!/bin/bash
sudo apt update -y
sudo apt install -y nodejs npm
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
echo "const http = require('http');
const port = 80;
const server = http.createServer((req, res) => { res.end('Hello from Node.js App'); });
server.listen(port);" > index.js
nohup node index.js &
