domena=$1

password=`tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16 | xargs`

if [ -z "$domena" ]; then exit 1;
fi

if [ -e "mysql_user.sql" ]; then
rm "mysql_user.sql"
fi

# remove dot from user name with dash

domena=`echo $domena | tr '.' '_'`

if [ `echo $domena | wc -c` -ge 18 ]; then
echo "too long username :/"
exit
fi

cat > mysql_user.sql << EOF
CREATE USER $domena@'172%' IDENTIFIED BY '$password';

GRANT USAGE ON *.* TO '$domena'@'%' IDENTIFIED BY '$password' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;

CREATE DATABASE $domena;

GRANT ALL PRIVILEGES ON $domena.* TO '$domena'@'localhost';
FLUSH PRIVILEGES ;
EOF

mysql -u root -p < mysql_user.sql

echo "finished creating DB + user: $domena , password: $password"