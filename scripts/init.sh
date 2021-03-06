#!/bin/bash

echo "Fixing up resolv.conf"
sed -i "/^search.*/a nameserver PIT_IP" /etc/resolv.conf

echo "Removing zero file"
rm /root/zero-file

if [ ! -f /usr/bin/check-default-route.sh ]; then
  echo "Setting up default route cronjob"

  echo "#!/bin/bash

  echo \"Checking that default route is set correctly\"
  output=\$(ip r | grep -q default)
  rc=\$?
  if [ "\$rc" -ne 0 ]; then
    echo "Adding default route"
    ip route add default via 10.248.0.1
  fi" > /usr/bin/check-default-route.sh

  chmod 755 /usr/bin/check-default-route.sh
  /usr/bin/check-default-route.sh
  echo "* * * * * root /usr/bin/check-default-route.sh" > /etc/cron.d/check-default-route
  systemctl restart cron
fi

echo "server ncn-s001 iburst maxsources 3 prefer
allow 10.248.0.0/18
local stratum 10
#local stratum 3 orphan
log measurements statistics tracking
logchange 1.0" >> /etc/chrony.d/cray.conf

sed -i 's/^#NTP=.*/NTP=ncn-s001/g' /etc/systemd/timesyncd.conf
sed -i -e '/rgwloadbalancers/,+4 s/^/#/' /etc/ansible/hosts
sed -i 's/bond0.nmn0/eth0/g' /etc/ansible/hosts
sed -i 's/bond0.nmn0/eth0/g' /srv/cray/scripts/common/storage-ceph-cloudinit.sh
sed -i 's/bond0.nmn0/eth0/g' /srv/cray/scripts/metal/lib-1.5.sh
sed -i 's/bond0.nmn0/eth0/g' /etc/ansible/ceph-rgw-users/roles/ceph-cephfs/templates/storageclasses.yaml.j2
sed -i 's/bond0.nmn0/eth0/g' /etc/ansible/ceph-rgw-users/roles/ceph-rbd/templates/ceph-rbd.storageclass.yaml.j2
sed -i 's/bond0.nmn0/eth0/g' /etc/ansible/ceph-rgw-users/roles/ceph-rbd/tasks/main.yml
sed -i 's/rgw-vip/ncn-s001:8080/' /opt/cray/platform-utils/s3/list-objects.py
sed -i 's/\/var\/lib\/s3fs_cache/\/tmp/' /srv/cray/scripts/metal/lib.sh

printf "Fix\n" | parted ---pretend-input-tty /dev/vda print
printf "Yes\n100%%\n" | parted ---pretend-input-tty /dev/vda resizepart 2
resize2fs /dev/vda2

#######
#  Maybe we can remove some of this now that cloud init works-ish
#######
if [[ "$(hostname)" =~ ^ncn-m ]] || [[ "$(hostname)" =~ ^ncn-w ]]; then
  sed -i 's/configure-load-balancer-for-master/#configure-load-balancer-for-master/' /srv/cray/scripts/common/kubernetes-cloudinit.sh
  sed -i 's/$(craysys metadata get k8s_virtual_ip)/kubernetes-api.nmn/' /srv/cray/scripts/metal/lib.sh
  sed -i 's/6442/6443/' /srv/cray/scripts/metal/lib.sh
  sed -i 's/2381/2379/' /srv/cray/scripts/metal/lib.sh
fi

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
   sed -i 's/http:\/\/rgw-vip.hmn:8080/http:\/\/ncn-s001:8080/g' /etc/ansible/ceph-rgw-users/roles/ceph-rgw-users/defaults/main.yml
   sed -i 's/https:\/\/rgw-vip.nmn/http:\/\/ncn-s001:8080/g' /etc/ansible/ceph-rgw-users/roles/ceph-rgw-users/defaults/main.yml
   sed -i 's/http:\/\/rgw-vip.nmn/http:\/\/ncn-s001:8080/g' /etc/ansible/ceph-rgw-users/roles/ceph-rgw-users/defaults/main.yml
 fi

timedatectl set-ntp true
systemctl daemon-reload
systemctl restart systemd-timedated.service
systemctl restart chronyd.service

systemctl stop cloud-init.target
rm -rf /var/lib/cloud/*.*
rm -rf /run/cloud-init/*.*
killproc cloud-init

if ! grep -q NoCloud /etc/cloud/cloud.cfg; then
echo "" >> /etc/cloud/cloud.cfg
echo "datasource:
  NoCloud:
    seedfrom: http://PIT_IP:8888/" >> /etc/cloud/cloud.cfg
fi

systemctl start cloud-init
cloud-init clean
cloud-init init
cloud-init modules -m init
cloud-init modules -m config
cloud-init modules -m final
