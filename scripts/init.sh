#!/bin/bash
route=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
#ip route add default via $route
ip route add 172.16.0.0/12 via $route dev eth0

echo "server ncn-s001 iburst maxsources 3 prefer
allow 10.248.0.0/18
local stratum 10
#local stratum 3 orphan
log measurements statistics tracking
logchange 1.0" >> /etc/chrony.d/cray.conf

sed -i 's/^#NTP=.*/NTP=ncn-s001/g' /etc/systemd/timesyncd.conf
sed -i -e '/rgwloadbalancers/,+4 s/^/#/' /etc/ansible/hosts
sed -i 's/vlan002/eth0/g' /etc/ansible/hosts


if [ $HOSTNAME == "ncn-s001" ]
  then
   echo "# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
#! pool pool.ntp.org iburst

# Record the rate at which the system clock gains/losses time.
driftfile /var/lib/chrony/drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second.
makestep 0.005 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Enable hardware timestamping on all interfaces that support it.
#hwtimestamp *

# Increase the minimum number of selectable sources required to adjust
# the system clock.
#minsources 2

# Allow NTP client access from local network.
allow 10.248.0.0/18

# Serve time even if not synchronized to a time source.
local stratum 10

# Specify file containing keys for NTP authentication.
#keyfile /etc/chrony.keys

# Get TAI-UTC offset and leap seconds from the system tz database.
#leapsectz right/UTC

# Specify directory for log files.
logdir /var/log/chrony

# Select which information is logged.
#log measurements statistics tracking

# Also include any directives found in configuration files in /etc/chrony.d
include /etc/chrony.d/*.conf
" >> /etc/chronyd.conf
 fi

timedatectl set-ntp true
systemctl daemon-reload
systemctl restart systemd-timedated.service
systemctl restart chronyd.service

cephadm --image dtr.dev.cray.com/ceph/ceph:v15.2.8 pull
