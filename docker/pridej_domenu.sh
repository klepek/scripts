domena=$1
port=$2

password=`tr -dc A-Za-z0-9_ < /dev/urandom | head -c 16 | xargs`

if [ -z "$domena" ]; then exit 1;
fi
if [ -z "$port" ]; then exit 1;
fi
# vyrob uzivatele
useradd -M -d / -G sftp -g www-data -o -u 33 $domena

# vyrob volume pre web
mkdir -p /volumes/$domena/log
mkdir -p /volumes/$domena/www
mkdir -p /volumes/$domena/etc
cp -pr /volumes/skel/* /volumes/$domena/etc
sed "s/_%_/$domena/g" /volumes/skel/site.conf > /volumes/$domena/etc/site.conf
touch /volumes/$domena/log/{access,php,error}.log

# vyrob docker
mkdir -p /root/templates/$domena
#cp -pr /root/templates/skel/* /root/templates/$domena
sed "s/_%_/$domena/g" /root/templates/skel/docker-compose.yaml | sed "s/_!_/$port/g"  > /root/templates/$domena/docker-compose.yaml
cd /root/templates/$domena
#docker-compose up -d

echo "$domena:$password" | chpasswd
echo "heslo pre $domena je: $password" | mail -s "heslo na $domena" -r root@zvratenyhumor.sk jan.klepek@gmail.com
echo "heslo pre $domena je: $password"

# prepare varnish
vdomena=`echo $domena | tr '.' '_'`
mkdir /etc/varnish/${domena}.d
sed "s/_%_/$vdomena/g" /root/templates/skel/varnish_backend | sed "s/_!_/$port/g"  > /etc/varnish/${domena}.d/backend
sed "s/_%_/$domena/g" /root/templates/skel/varnish_recv | sed "s/_!_/$vdomena/g"  > /etc/varnish/${domena}.d/recv
echo "include \"${domena}.d/backend\";" >> /etc/varnish/.all_backend_includes.vcl
echo "include \"${domena}.d/recv\";" >> /etc/varnish/.all_recv_includes.vcl
varnishd -C -f /etc/varnish/default.vcl >/dev/null 2>&1
err=$?
echo "varnish check: $err"

# setup systemd
sed "s/_%_/$domena/g" /root/templates/skel/systemd.service > /etc/systemd/system/${domena}.service