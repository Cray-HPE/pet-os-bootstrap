#!/bin/bash
# Create Volume

# I think we need to build something in that makes either k8s or ceph optional.
# they could technically build mercury using this as well.
# below code to test
while getopts k:c:a:i:K:S: stack
do
  case "${stack}" in
          k) k8s=$OPTARG;;
          i) sshkey=$OPTARG;;
          c) ceph=$OPTARG;;
          a) all=$OPTARG;;
          K) k8s_snapshot=$OPTARG;;
          S) storage_snapshot=$OPTARG;;
  esac
done

echo "Removing ncn ips from /etc/hosts"
sed -i -e '/DELETE_BELOW/q0' /etc/hosts

echo "Cleaning up init.sh with PIT_IP"
pit_ip=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
sed -i -e "s/PIT_IP/$pit_ip/" ./init.sh

echo "k8s $k8s"
echo "ceph $ceph"
echo "all $all"
echo "sshkey $sshkey"
echo "k8s snapshot: $k8s_snapshot"
echo "storage snapshot: $storage_snapshot"

if  [ "$ceph" = "true" ] || [ "$all" = "true" ]
then
  echo "Creating boot and OSD volumes for CEPH"
  for num in 1 2 3
  do
   openstack volume create --size 25 --type RBD osd.$num
   openstack volume create --size 45 --type RBD --bootable --snapshot $storage_snapshot ncn-s00$num
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
  echo "Creating boot volumes for K8S masters"
  for num in 1 2 3
  do
    openstack volume create --size 150 --type RBD --snapshot $k8s_snapshot --bootable ncn-m00$num
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
  echo "Creating boot volumes for K8S workers"
  for num in 1 2 3
  do
    openstack volume create --size 150 --type RBD --snapshot $k8s_snapshot --bootable ncn-w00$num
  done
fi

counter=1
until [ $counter -eq 0 ]
do
 counter=0
 echo "Checking status of boot volumes"
 clear
 for vol in $(openstack volume list -f json| jq -r '.[]| select(.Name|contains ("ncn-"))|.ID')
  do
    status=$(openstack volume show $vol -f json|jq -r .status)
    if [ "$status" != "available" ]
    then
    counter=+1
    echo "Status of volume $vol is: $status"
    fi
  done
done

# use to get volume and server names
echo "sleeping 20 second...zzz.."
sleep 20

if  [ "$ceph" = "true" ] || [ "$all" = "true" ]
then
 echo "Creating vms for ceph"
 for node in 2 3
 do
   openstack server create --flavor highmem.2  --key-name $sshkey --user-data init.sh  --volume ncn-s00$node --network Cray_Network ncn-s00$node
 done

 for node in 1
 do
   openstack server create --flavor highmem.2  --key-name $sshkey --user-data init.sh  --volume ncn-s00$node --network Cray_Network ncn-s00$node
 done
fi

#read -p "Press [Enter] key to keep going with k8s build..."

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
 echo "Creating master vms for K8S"
 for node in 1 2 3
  do
   openstack server create --flavor standard.2 --key-name $sshkey --user-data init.sh --volume ncn-m00$node --network Cray_Network ncn-m00$node
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
 echo "Creating worker vms for K8S"
 for node in 1 2 3
  do
   openstack server create --flavor highcpu.16 --key-name $sshkey --user-data init.sh --volume ncn-w00$node --network Cray_Network ncn-w00$node
  done
fi

# put conditional here based off status
#openstack server list -f json |jq '.[]| {Name, Status}'
echo "Sleeping for 10 seconds ...ZZZ..."
sleep 10
for vol in 1 2 3
 do
  openstack server add volume ncn-s00$vol osd.$vol
done

cp /var/www/ephemeral/configs/data.orig /var/www/ephemeral/configs/data.json
for node in $(openstack server list -f json| jq -r .[].Name|egrep -i 'ncn-m00')
do
 ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 while [ -z "$ip" ]; do
    echo "Waiting for ip to get assigned for $node"
    sleep 2
    ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 done

 until ping -c1 "$ip" 2>&1 >/dev/null; do echo "Waiting for node ${node}'s ip (${ip}) to have a mac address"; sleep 2; done
 mac="$(ip -r -br n show to $ip|awk '{print $5}')"
 echo "Node $node has ip: $ip and mac: $mac"
 echo "$ip $node $node.nmn kubernetes-api.nmn" >> /etc/hosts
 sed -i -e "s/IPADDR-$node/$ip/" /var/www/ephemeral/configs/data.json
 sed -i -e "s/mac-$node/$mac/" /var/www/ephemeral/configs/data.json
done

echo "Restarting dnsmasq and basecamp for masters updates"
systemctl restart dnsmasq.service
podman restart basecamp

for node in $(openstack server list -f json| jq -r .[].Name|egrep -i 'ncn-[ws]')
do
 ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 while [ -z "$ip" ]; do
    echo "Waiting for ip to get assigned for $node"
    sleep 2
    ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 done

 until ping -c1 "$ip" 2>&1 >/dev/null; do echo "Waiting for node ${node}'s ip (${ip}) to have a mac address"; sleep 2; done
 mac="$(ip -r -br n show to $ip|awk '{print $5}')"
 echo "Node $node has ip: $ip and mac: $mac"
 echo "$ip $node $node.nmn" >> /etc/hosts
 sed -i -e "s/IPADDR-$node/$ip/" /var/www/ephemeral/configs/data.json
 sed -i -e "s/mac-$node/$mac/" /var/www/ephemeral/configs/data.json
 echo "Restarting dnsmasq and basecamp"
 systemctl restart dnsmasq.service
 podman restart basecamp
done
