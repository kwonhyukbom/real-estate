#!/bin/bash
apt-get install apache2 -y
mkdir -p /var/www/html/uploads
cp ./index.html ./index.php /var/www/html/
service apache2 start
echo $(curl localhost)
