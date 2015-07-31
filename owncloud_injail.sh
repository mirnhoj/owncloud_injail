#!/bin/sh
######## START OF CONFIGURATION SECTION####################################


#   In order to use this script, the following variables must be defined 
#   	by the user:
#
#     server_port - This value is used to specify which port Owncloud 
#	will be listening to. This is necessary because some installations of 
#	N4F have had trouble with the administrative webgui showing up, even 
#	when browsing to the jail's IP.
#     
#	  server_ip - This value is used to specify which ip address Owncloud 
#	will be listening to. This is necessary because it keeps the jail from
#   listening on all ip's
#
#    owncloud_version - This is the version of owncloud you would like 
#	to download.


server_port="81"
server_ip="192.168.1.101"
owncloud_version="8.1.0"   # Also edit line 200 (fetch "http://download.owncloud.org/community/owncloud-8.0.3.tar.bz2") so that it matches this line.



### END OF CONFIGURATION SECTION##############################################

#
#	This is a simple script to automate the installation of Owncloud within a 
#	jailed environment.
#   Copyrighted 2013 by Matthew Kempe under the Beerware License.

# define our bail out shortcut function anytime there is an error - display 
# the error message, then exit returning 1.
exerr () { echo -e "$*" >&2 ; exit 1; }


## Begin sanity checks
# None, as this script is intended to be run from the command line

echo "################################################" 
echo "#   Welcome to the owncloud installer!"
echo "################################################ " 

echo " " 
echo "################################################" 
echo "#   Let's start by installing some stuff!!"
echo "################################################ "
echo " "
## End sanity checks
# Install packages
pkg install -y lighttpd php5-openssl php5-ctype php5-curl php5-dom php5-fileinfo php5-filter php5-gd php5-hash php5-iconv php5-json php5-mbstring php5-mysql php5-pdo php5-pdo_mysql php5-pdo_sqlite php5-session php5-simplexml php5-sqlite3 php5-xml php5-xmlrpc php5-xmlwriter php5-gettext php5-mcrypt php5-zip php5-zlib mp3info mysql56-server

echo " " 
echo "################################################" 
echo "Packages installed - now configuring mySQL"
echo "################################################ "
echo " "
echo 'mysql_enable="YES"' >> /etc/rc.conf
echo '[mysqld]' >> /var/db/mysql/my.cnf 
echo 'skip-networking' >> /var/db/mysql/my.cnf

/usr/local/etc/rc.d/mysql-server start
echo " " 
echo "################################################" 
echo "Getting ready to secure the install. The root password is blank, "
echo "and you want to provide a strong root password, remove the anonymous accounts" 
echo "disallow remote root access, remove the test database, and reload privilege tables"
echo "################################################ "
echo " "
mysql_secure_installation

echo " " 
echo "################################################" 
echo "Done hardening mySQL - performing key operations"
echo "################################################ "
echo " "
cd ~
openssl genrsa -des3 -out server.key 1024
echo " " 
echo "################################################" 
echo "Removing password from key"
echo "################################################ "
echo " "
openssl rsa -in server.key -out no.pwd.server.key
echo " " 
echo "################################################" 
echo "Creating cert request. The Common Name should match whatever URL you want to use"
echo "################################################ "
echo " "
openssl req -new -key no.pwd.server.key -out server.csr

echo " " 
echo "################################################" 
echo "Creating cert & pem file & moving to proper location"
echo "################################################ "
echo " "
openssl x509 -req -days 365 -in /root/server.csr -signkey /root/no.pwd.server.key -out /root/server.crt
cat no.pwd.server.key server.crt > server.pem
mkdir /usr/local/etc/lighttpd/ssl
cp server.crt /usr/local/etc/lighttpd/ssl
chown -R www:www /usr/local/etc/lighttpd/ssl/
chmod 0600 server.pem

echo " " 
echo "################################################" 
echo "Creating backup of lighttpd config"
echo "################################################ "
echo " " 
cp /usr/local/etc/lighttpd/lighttpd.conf /usr/local/etc/lighttpd/old_config.bak

echo " " 
echo "################################################" 
echo "Modifying lighttpd.conf file"
echo "################################################ "
echo " "
cat "/usr/local/etc/lighttpd/old_config.bak" | \
	sed -r '/^var.server_root/s|"(.*)"|"/usr/local/www/owncloud"|' | \
	sed -r '/^server.use-ipv6/s|"(.*)"|"disable"|' | \
	sed -r '/^server.document-root/s|"(.*)"|"/usr/local/www/owncloud"|' | \
	sed -r '/^#server.bind/s|(.*)|server.bind = "'"${server_ip}"'"|' | \
	sed -r '/^\$SERVER\["socket"\]/s|"0.0.0.0:80"|"'"${server_ip}"':'"${server_port}"'"|' | \
	sed -r '/^server.port/s|(.*)|server.port = '"${server_port}"'|' > \
	"/usr/local/etc/lighttpd/lighttpd.conf"

echo " " 
echo "################################################" 
echo "Adding stuff to lighttpd.conf file"
echo "################################################ "
echo " "

echo 'ssl.engine = "enable"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'ssl.pemfile = "/root/server.pem"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'ssl.ca-file = "/usr/local/etc/lighttpd/ssl/server.crt"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'ssl.cipher-list  = "ECDHE-RSA-AES256-SHA384:AES256-SHA256:RC4-SHA:RC4:HIGH:!MD5:!aNULL:!EDH:!AESGCM"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'ssl.honor-cipher-order = "enable"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'ssl.disable-client-renegotiation = "enable"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo '$HTTP["url"] =~ "^/data/" {' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'url.access-deny = ("")' >> /usr/local/etc/lighttpd/lighttpd.conf
echo '}' >> /usr/local/etc/lighttpd/lighttpd.conf
echo '$HTTP["url"] =~ "^($|/)" {' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'dir-listing.activate = "disable"' >> /usr/local/etc/lighttpd/lighttpd.conf
echo '}' >> /usr/local/etc/lighttpd/lighttpd.conf
echo 'cgi.assign = ( ".php" => "/usr/local/bin/php-cgi" )' >> /usr/local/etc/lighttpd/lighttpd.conf

echo " " 
echo "################################################" 
echo "Enabling the fastcgi module"
echo "################################################ "
echo " "
cp /usr/local/etc/lighttpd/modules.conf /usr/local/etc/lighttpd/old_modules.bak
cat "/usr/local/etc/lighttpd/old_modules.bak" | \
	sed -r '/^#include "conf.d\/fastcgi.conf"/s|#||' > \
	"/usr/local/etc/lighttpd/modules.conf"

echo " " 
echo "################################################" 
echo "Adding stuff to fastcgi.conf file"
echo "################################################ "
echo " "
echo 'fastcgi.server = ( ".php" =>' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '((' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"socket" => "/tmp/php.socket",' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"bin-path" => "/usr/local/bin/php-cgi",' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"bin-environment" => (' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"PHP_FCGI_CHILDREN" => "16",' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"PHP_FCGI_MAX_REQUESTS" => "10000"' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '),' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"min-procs" => 1,' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"max-procs" => 1,' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '"idle-timeout" => 20' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo '))' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf
echo ' )' >> /usr/local/etc/lighttpd/conf.d/fastcgi.conf

echo " " 
echo "################################################" 
echo "Obtaining corrected MIME .conf file for lighttpd to use"
echo "################################################ "
echo " "

mv /usr/local/etc/lighttpd/conf.d/mime.conf /usr/local/etc/lighttpd/conf.d/mime_conf.bak
fetch -o /usr/local/etc/lighttpd/conf.d/mime.conf http://www.xenopsyche.com/mkempe/oc/mime.conf

echo " " 
echo "################################################" 
echo "Packages installed - creating www folder"
echo "################################################ "
echo " "
mkdir /usr/local/www

echo " "
# Get owncloud, extract it, copy it to the webserver, and have the jail 
# assign proper permissions
echo "################################################" 
echo "www folder created - now downloading owncloud"
echo "################################################ "
echo " "
cd "/tmp"
fetch "https://download.owncloud.org/community/owncloud-8.1.0.tar.bz2"
tar xf "owncloud-${owncloud_version}.tar.bz2" -C /usr/local/www
chown -R www:www /usr/local/www/

echo " " 
echo "################################################" 
echo "Adding lighttpd to rc.conf"
echo "################################################ "
echo " "
echo 'lighttpd_enable="YES"' >> /etc/rc.conf

echo " " 
echo "################################################" 
echo "  Done, lighttpd should start up automatically!"
echo "################################################ "
echo " "

echo " "
echo "################################################" 
echo "Attempting to start webserver."
echo "If it fails and says Cannot 'start' lighttpd, manually add"
echo "    lighttpd_enable="YES" to /etc/rc.conf"
echo "Command being run here is:"
echo "    /usr/local/etc/rc.d/lighttpd start"
echo "################################################ "
echo " "
/usr/local/etc/rc.d/lighttpd start

echo " " 
echo "################################################" 
echo "  It looks like we finished!!! NICE"
echo " Now you can head to your ip:port as defined at the start of this script "
echo " via your browser and complete your OwnCloud setup!"
echo "################################################ "
echo " "
