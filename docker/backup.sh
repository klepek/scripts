weekOLD=`date +'%Y%V' --date='4 week ago'`
nextREMOVE=`date +'%Y%V' --date='3 week ago'`
# dirnameOLD - path/week number of the backup
dirnameOLD=/backup/$weekOLD
olddir=/backup/$nextREMOVE

# backup dbs into /backup/$date/db
targetdir=/backup/`date +'%Y%V'`

dbtargetdir=$targetdir/db
voltargetdir=$targetdir/volumes
dockertargetdir=$targetdir/docker
conttargetdir=$targetdir/containers
scriptstargetdir=$targetdir/scripts
LOGFILE=/tmp/`date +'%Y%V'`.backup.log
mkdir -p $targetdir
mkdir -p $dbtargetdir
mkdir -p $voltargetdir
mkdir -p $dockertargetdir/{Dockerfiles,templates,images}
mkdir -p $conttargetdir
mkdir -p $scriptstargetdir

#touch/clean existing log
echo "" > $LOGFILE

# remove oldest directory
rm -rf $dirnameOLD

# backup templates & dockerfiles
cp /backup.sh $scriptstargetdir/
cd ~root/scripts
echo "Scripts backup" >> $LOGFILE
cp * $scriptstargetdir/
echo "\tScripts backup result $? with error: $!" >> $LOGFILE
# backup templates & dockerfiles
cd ~root/templates
echo "Templates & dockerfiles backup" >> $LOGFILE
for i in *; do
tar -czf $dockertargetdir/templates/${i}.tar.gz $i >> $LOGFILE
echo "\tTemplates backup $i result $? with error: $!" >> $LOGFILE
done
cd ~root/Dockerfiles
for i in *; do
tar -czf $dockertargetdir/Dockerfiles/${i}.tar.gz $i >> $LOGFILE
echo "\tDockerfiles backup $i result $? with error: $!" >> $LOGFILE
done
echo "Images backup" >> $LOGFILE
docker images --format={{.Repository}} -f "dangling=false" | while read line; do
file=`echo $line | sed -e 's#\/#\_#g'`
docker save $line | xz -c9 > $dockertargetdir/images/${file}.tar.xz 
echo "\tImage backup $line result $? with error: $!" >> $LOGFILE
done

# db backup
echo "DB backup" >> $LOGFILE
echo "show databases;" | mysql -N -u root --password='' |grep -vE 'information_schema' | grep -vE 'performance_schema' |  while read line; do
        mysqldump $line -u root --password=''| xz -c9 > "$dbtargetdir/${line}.db.tar.xz"
        echo "\tbackup $line result $? with error: $!" >> $LOGFILE
done

# backup volumes
echo "Volumes backup" >> $LOGFILE
lvcreate -L2G -s -n vol_snap /dev/VolGroup00/lv_volumes >> $LOGFILE 2>&1
mount /dev/VolGroup00/vol_snap /mnt/snapshot
cd /mnt/snapshot; 
for i in *; do
tar -czf $voltargetdir/${i}.tar.gz $i >> $LOGFILE
echo "\tbackup $i result $? with error: $!" >> $LOGFILE
done
cd /
umount /mnt/snapshot
lvremove -f /dev/VolGroup00/vol_snap

cursize=`du -msx $targetdir | cut -f 1`
oldsize=`du -msx $olddir | cut -f 1`
free=`df -hP /backup | grep backup`

# we are done, sent status to email
echo "backup size: $cursize" >> $LOGFILE
echo "next to remove backup size: $oldsize" >> $LOGFILE
echo -e "free:\n $free" >> $LOGFILE
mail -s "backup `hostname`" -r root@host email@email< $LOGFILE