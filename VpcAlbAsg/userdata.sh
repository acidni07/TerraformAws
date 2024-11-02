#!/bin/bash
apt-get update -y
apt-get install apache2 -y
echo "This page is hosted on Apache WS running on EC2 launched by ASG" > /var/www/html/index.html
systemclt start apache2