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

# Adding user since root ssh access is being removed
useradd -m -d /home/crayon -s /bin/bash -p '$6$wLwZtEX5r/jWAAzo$1.ci6aK1.znBMaPB0H2HrDVqoh3rD/VNYO.CZVcs42/I1rmUaBordIaCay4NNBJ50/HBeqjUvBScZywkSTsqy/' crayon
sed -i -e '/root ALL=(ALL) ALL/a\' -e 'crayon ALL=(ALL) NOPASSWD: ALL' /etc/sudoers

mkdir -p /root/.ssh
cat > /root/.ssh/id_rsa << EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEArq+xyoMdc32q0rhB0DErNl8xK8AyXN1jfK0p89PsN/UCc9OC
raRZ8xftD9uTgrQsGQBsInIJcxUlIApGfit+eQZBhycCSfW3IBt2g3JdGwFMGrT4
llfC7pTLQS4IgHl9WmyKGRoiYlDdyAHWzSIcKYeyY6DFIM0zNV0FW7LwpbrtzxU8
dh2vNjUBsojQjdY9YFgWytlOHz60s4k3yWMuXpRH2uLrv4ka3pr22Q+NTG+lMWAw
Ukxo2Uhb/sdeAFroFxGjIuZxQBXjkLSWpPmAgoYMa72mJYiTJpHhXcGEnFaNbZz4
ipgLtxdnMEaPymQkeGcUpIso8BJIt+AJp9uVkQIDAQABAoIBAH8BrNFhjOsoRifY
4bjd1t48TcLShYtxR2EhgawOu+NfVv4hnRRktyWAktKBwfk4yAsRfI16vhYXHJvz
/JbFRrn1a3U5Tne5mABXF06wurLkuZF9XHPqsQbH1hO4xWOrcRFqcumXT8KNqwI9
HBCfKTyktXWsMUcNCptU2411R3Qmhil5wdgJQNrEl1qMiLOBeTrE5gEBh9nylIoC
UW5tejBUX+9/LTFmyYb249Mb32aNPDDxe76PFTeNUvqYmh8xv1KbdD2sCIYWxmk+
snUujljMxAETylepItFF0DOQsVwS8posvwRAgxsqKTDNaGma92Tbh33fSgNwjBDW
zNO7y6UCgYEA17o8eUZucy0ifh4Kvmey7etT5Jvig9EtL8ZK4byCspd//FO0Q081
FwK0YycYlP8YSO+mIAefU2YZC8qRPNqxW5/TmrvdObsXfy9TbmbnjXmcsQVdwHxv
jHnoNgmOLqQdQGbqQ+jg2CPHSp+DjmdiQQ60lotny5moOs1YPTnT5C8CgYEAz0wS
hDLi1XCULni7lKez/xj2EpfMDqRh9JwPAEA7+HYKf9Np7M1hz/X3ZlWKiXZxmgT5
l1fRhwjTVMgneBfkmg0ePmxq+zzwnTC8OCbE3DMCw+SRXE6cCOxjsDXpBwqtWIn+
B1k8c4cI+ebKUP+IAUvdDXbkPKbow9CbuNae8j8CgYAdKGToF2byVlVlKnZVSfrb
QYVzTsaM/obXADw6ypn3vZZk6oNg3aHVXF45UJ139gq4QPv5NE6KnTAhcd2zlfOG
6NFXBrFeDjWc0S67q1j8vEU7f/gt/iOtnwSN2TjIgRIbFE3xo9ZQIHXdVjYX101m
cbBi8LC0yi381KhqjhhfrQKBgE5/Xw+ieVUb0XEblOTA8J8r45q80q/Evbc0FVYh
/NOkV2t6MkVSrLRkTu/4eoJ9UJ1jPuR5g8VfqS8UsCWA3rcbOpWm1ogW1oKfvtaA
j9FWm7h0aDsNJXcXlNRYRcq911CMyJ4dw4931gVTyM8NRIJBKQ79M4ZoKgJkj2Na
GkxfAoGASe0i9N3Auk7opsDK+CgyujVuR2YF3hpro1fiW8Z8UWbseOPBnMTUVWZa
gsXsdmcoFiHp3IcJ2aqjwrbTGnIduU00vn6IGBRTxI2upCIrawQN24Jqjgw/PJ17
lp3iQ80542iRxFeV/XQTpUzR5dUWLOrD1kHtq28nmNcS6ZivWfE=
-----END RSA PRIVATE KEY-----
EOF
cat > /root/.ssh/id_rsa.pub << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCur7HKgx1zfarSuEHQMSs2XzErwDJc3WN8rSnz0+w39QJz04KtpFnzF+0P25OCtCwZAGwicglzFSUgCkZ+K355BkGHJwJJ9bcgG3aDcl0bAUwatPiWV8LulMtBLgiAeX1abIoZGiJiUN3IAdbNIhwph7JjoMUgzTM1XQVbsvCluu3PFTx2Ha82NQGyiNCN1j1gWBbK2U4fPrSziTfJYy5elEfa4uu/iRremvbZD41Mb6UxYDBSTGjZSFv+x14AWugXEaMi5nFAFeOQtJak+YCChgxrvaYliJMmkeFdwYScVo1tnPiKmAu3F2cwRo/KZCR4ZxSkiyjwEki34Amn25WR
EOF
cat > /root/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCur7HKgx1zfarSuEHQMSs2XzErwDJc3WN8rSnz0+w39QJz04KtpFnzF+0P25OCtCwZAGwicglzFSUgCkZ+K355BkGHJwJJ9bcgG3aDcl0bAUwatPiWV8LulMtBLgiAeX1abIoZGiJiUN3IAdbNIhwph7JjoMUgzTM1XQVbsvCluu3PFTx2Ha82NQGyiNCN1j1gWBbK2U4fPrSziTfJYy5elEfa4uu/iRremvbZD41Mb6UxYDBSTGjZSFv+x14AWugXEaMi5nFAFeOQtJak+YCChgxrvaYliJMmkeFdwYScVo1tnPiKmAu3F2cwRo/KZCR4ZxSkiyjwEki34Amn25WR
EOF
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub
chmod 644 /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chown -R root:root /root


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
