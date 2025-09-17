#!/bin/bash
if [ -f /var/run/nodejs-app.pid ]; then
  kill $(cat /var/run/nodejs-app.pid) || true
  rm -f /var/run/nodejs-app.pid
fi
pkill -f "npm start" || true
pkill -f "node" || true
