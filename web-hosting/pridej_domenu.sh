domena=$1

password=`tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16 | xargs`

if [ -z "$domena" ]; then exit 1;
fi
useradd -U -M -d /www -G apache,sftp $domena

# pridej uzivatele
mkdir -p /var/www/$domena/www
mkdir -p /var/www/$domena/tmp
mkdir -p /var/www/$domena/log
#mkdir -p /var/log/nginx/$domena

chgrp -R $domena /var/www/$domena
chown -R $domena /var/www/$domena/www
chown -R $domena /var/www/$domena/tmp
chown -R $domena /var/www/$domena/log
ln -s /var/www/$domena/log /var/log/nginx/$domena

chmod 755 /var/www/$domena
echo "$domena:$password" | chpasswd
# udelej konfig pre nginx
sed "s/_%_/$domena/g" /etc/nginx/sites-available/default > /etc/nginx/sites-enabled/$domena

# udelej config pre php-fpm
cat << EOT | sed "s/_%_/$domena/g" > /etc/php-fpm.d/${domena}.conf
[_%_]

 listen = /var/run/php7-fpm/_%_.socket
 listen.backlog = -1
 listen.owner = _%_
 listen.group = _%_
 listen.mode=0660

 ; Unix user/group of processes
 user = _%_
 group = _%_

 ; Choose how the process manager will control the number of child processes.
 pm = dynamic
 pm.max_children = 30
 pm.start_servers = 10
 pm.min_spare_servers = 5
 pm.max_spare_servers = 20
 pm.max_requests = 500

 catch_workers_output = yes

 ; Pass environment variables
 env[HOSTNAME] = $HOSTNAME
 env[PATH] = /usr/local/bin:/usr/bin:/bin
 env[TMP] = /tmp
 env[TMPDIR] = /tmp
 env[TEMP] = /tmp

 ; host-specific php ini settings here
 php_admin_value[open_basedir] = /var/www/_%_/www:/var/www/_%_/tmp;/www;/tmp
 php_admin_value[session.save_path] = /var/www/_%_/tmp
 php_admin_value[upload_tmp_dir] = /var/www/_%_/tmp
 php_admin_value[error_log] = /var/www/_%_/log/php.log
 php_admin_flag[log_errors] = on

EOT
# pridej config pre varnish

echo "heslo pre $domena je: $password" | mail -s "heslo na $domena" -r root@brandforge.sk jan.klepek@gmail.com
echo "heslo pre $domena je: $password"