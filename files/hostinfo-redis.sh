#!/bin/bash

# script to be run periodically to store on the local redis
#  database some information about the host, relevant to our
#  operations, so that it is accessible to any other redis client

# maybe it could be written more efficiently. Like it is now, it runs
#  in about 54ms; each tail, tr, cut adds to it
# Note that in order to be fast we check a single, specific sensor chip

if [ $HOSTNAME = 'last0' ]; then
   mountpoints="/ /$HOSTNAME/data1 /$HOSTNAME/data2 /$HOSTNAME/data3"
else
   mountpoints="/ /$HOSTNAME/data /$HOSTNAME/data1 /$HOSTNAME/data2"
fi

echo hset $HOSTNAME.uptime t `date +%s.%N` v \"`uptime -s`\"| redis-cli

echo hset $HOSTNAME.availMem t `date +%s.%N` v \
    \"`grep Avail /proc/meminfo | tr -s ' '|cut -f 2 -d ' '`\" \
   | redis-cli
   
# removing APM here is a trick because in some circumstances the time field includes AM/PM!
#echo hset $HOSTNAME.userCPU t `date +%s.%N` v \
#   \"`mpstat | tail -1 | tr -d 'APM' | tr -s '[:blank:]' | cut -f 3 -d ' '`\" \
#   | redis-cli

echo hset $HOSTNAME.Tctl t `date +%s.%N` v \
   \"`sensors -A k10temp-pci-00c3 | grep Tctl: | tr -s ' '| cut -f 2 -d ' '| tr -d '+°C'`\" \
   | redis-cli

for mountp in $mountpoints ; do
   if [[ -z `lsblk | grep $mountp$` ]]; then
     diskpercent="NO DISK!"
   else
     diskpercent=`(ls $mountp > /dev/null 2>&1 && df --output=pcent $mountp | tail -1| tr -d '%') || echo 'ERROR!'`
   fi
   echo hset $HOSTNAME.diskUsage$mountp t `date +%s.%N` v "$diskpercent" | redis-cli
done

