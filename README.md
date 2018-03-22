# shopware-nginx-virtualhost
Short Shellscript to create VHost with nginx and shopware

**Why?**
Shopware needs some specific webserver configurations
**For who?**
Webdevelopers who work intensely with shopware and often switch between installations or have +5 installations

## Syntax
sudo ./shopware-nginx.sh OPTION DOMAIN DOCROOT

### Create Vhost
sudo ./shopware-nginx.sh create dev.test.de /var/www/shopware

### Delete Vhost
sudo ./shopware-nginx.sh delete dev.test.de /var/www/shopware

WARNING: Choose n if you do NOT want to delete your DOCROOT


Thanks to following Repos:
https://github.com/bcremer/shopware-with-nginx
https://github.com/RoverWire/virtualhost

