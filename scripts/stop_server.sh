#!/bin/bash
set -e
sudo chown -R www-data:www-data /var/www/html
sudo systemctl start nginx
sudo systemctl reload nginx
exit 0
