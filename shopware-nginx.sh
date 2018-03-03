#!/bin/bash

. global.conf
### Set default parameters
action=$1
domain=$2
rootDir=$3

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g.dev,staging"
	read domain
done

if [ "$rootDir" == "" ]; then
	rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain already exists.\nPlease Try Another one"
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $userDir$rootDir ]; then
			### create the directory
			mkdir $userDir$rootDir
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $userDir$rootDir/phpinfo.php
				then
					echo $"ERROR: Not able to write in file $userDir/$rootDir/phpinfo.php. Please check permissions."
					exit;
			else
					echo $"Added content to $userDir$rootDir/phpinfo.php."
			fi
		fi

		### create virtual host rules file
		if ! echo "## Author: Benjamin Cremer
## Shopware nginx rules.
## Heavily Inspired by https://github.com/perusio/drupal-with-nginx/
## Designed to be included in any server {} block.
## Please note that you need a PHP-FPM upstream configured in the http context, and its name set in the $fpm_upstream variable.
## https://github.com/bcremer/shopware-with-nginx

server {
        listen 80;
        listen [::]:80;
        server_name $domain;

        root $userDir$rootDir;


location = /favicon.ico {
    log_not_found off;
    access_log off;
}

## Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}

## Deny all attems to access possible configuration files
location ~ \.(tpl|yml|ini|log)$ {
    deny all;
}

## Deny access to media upload folder
location ^~ /media/temp/ {
    deny all;
}

# Shopware caches and logs
location ^~ /var/ {
    deny all;
}

# Deny access to root files
location ~ (autoload\.php|composer\.(json|lock|phar)|CONTRIBUTING\.md|eula.*\.txt|license\.txt|README\.md|UPGRADE\.md)$ {
    return 404;
}

location ^~ /files/documents/ {
    deny all;
}

# Block direct access to ESDs, but allow the follwing download options:
#  * 'PHP' (slow)
#  * 'X-Accel' (optimized)
# Also see http://wiki.shopware.com/ESD_detail_1116.html#Ab_Shopware_4.2.2
location ^~ /files/552211cce724117c3178e3d22bec532ec/ {
    internal;
}

# Shopware install / update
location /recovery/install {
    index index.php;
    try_files  \$uri /recovery/instsall/index.php\$is_args\$args;
}

location /recovery/update/ {
    location /recovery/update/assets {
    }
    if (!-e \$request_filename){
        rewrite . /recovery/update/index.php last;
    }
}

location / {
    location ~* \"^/themes/Frontend/Responsive/frontend/_public/vendors/fonts/open-sans-fontface/(?:.+)\.(?:ttf|eot|svg|woff)$\" {
        expires max;
        add_header Cache-Control \"public\";
        access_log off;
        log_not_found off;
    }

    location ~* \"^/themes/Frontend/Responsive/frontend/_public/src/fonts/(?:.+)\.(?:ttf|eot|svg|woff)$\" {
        expires max;
        add_header Cache-Control \"public\";
        access_log off;
        log_not_found off;
    }

    location ~* \"^/web/cache/(?:[0-9]{10})_(?:.+)\.(?:js|css)$\" {
        expires max;
        add_header Cache-Control \"public\";
        access_log off;
        log_not_found off;
    }


    ## All static files will be served directly.
    location ~* ^.+\.(?:css|cur|js|jpe?g|gif|ico|png|svg|html)$ {
        ## Defining rewrite rules
        rewrite files/documents/.* /engine last;
        rewrite backend/media/(.*) /media/create last;

        expires 1w;
        add_header Cache-Control \"public, must-revalidate, proxy-revalidate\";

        access_log off;
        # The directive enables or disables messages in error_log about files not found on disk.
        log_not_found off;

        tcp_nodelay off;
        ## Set the OS file cache.
        open_file_cache max=3000 inactive=120s;
        open_file_cache_valid 45s;
        open_file_cache_min_uses 2;
        open_file_cache_errors off;

        ## Fallback to shopware
        ## comment in if needed
        try_files \$uri /shopware.php?controller=Media&action=fallback;
    }

    index shopware.php index.php;
    try_files \$uri \$uri /shopware.php\$is_args\$args;
}

## XML Sitemap support.
location = /sitemap.xml {
    log_not_found off;
    access_log off;
    try_files \$uri @shopware;
}

## XML SitemapMobile support.
location = /sitemapMobile.xml {
    log_not_found off;
    access_log off;
    try_files \$uri @shopware;
}

## robots.txt support.
location = /robots.txt {
    log_not_found off;
    access_log off;
    try_files \$uri @shopware;
}

location @shopware {
    rewrite / /shopware.php;
}

location ~ \.php$ {
    try_files \$uri \$uri/ =404;

    ## NOTE: You should have \"cgi.fix_pathinfo = 0;\" in php.ini
    fastcgi_split_path_info ^(.+\.php)(/.+)$;

    ## required for upstream keepalive
    # disabled due to failed connections
    #fastcgi_keep_conn on;

    include fastcgi.conf;

    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

    # Mitigate httpoxy vulnerability, see: https://httpoxy.org/
    fastcgi_param HTTP_PROXY \"\";

    fastcgi_buffers 8 16k;
    fastcgi_buffer_size 32k;

    client_max_body_size 24M;
    client_body_buffer_size 128k;

    ## Set upstream in your server block
    fastcgi_pass unix:/run/php/php7.0-fpm.sock;
}

}
" > $sitesAvailable$domain
		then
			echo -e $"There is an ERROR create $domain file"
			exit;
		else
			echo -e $"\nNew Virtual Host Created\n"
		fi

		### Add domain in /etc/hosts
		if ! echo "127.0.0.1	$domain" >> /etc/hosts
			then
				echo $"ERROR: Not able write in /etc/hosts"
				exit;
		else
				echo -e $"Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == "" ]; then
			chown -R $(whoami):www-data $userDir$rootDir
		else
			chown -R $owner:www-data $userDir$rootDir
		fi

		### enable website
		ln -s $sitesAvailable$domain $sitesEnable$domain

		### restart Nginx
		service nginx restart

		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $userDir$rootDir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailable$domain ]; then
			echo -e $"This domain dont exists.\nPlease Try Another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			rm $sitesEnable$domain

			### restart Nginx
			service nginx restart

			### Delete virtual host rules files
			rm $sitesAvailable$domain
		fi

		### check if directory exists or not
		if [ -d $userDir$rootDir ]; then
			echo -e $"Delete host root directory ? (s/n)"
			read deldir

			if [ "$deldir" == 's' -o "$deldir" == 'S' ]; then
				### Delete the directory
				rm -rf $userDir$rootDir
				echo -e $"Directory deleted"
			else
				echo -e $"Host directory conserved"
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed Virtual Host $domain"
		exit 0;
fi
