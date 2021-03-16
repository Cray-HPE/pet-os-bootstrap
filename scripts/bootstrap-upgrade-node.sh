#!/bin/bash

while getopts n: options
do
  case "${options}" in
          n) rebuild_node=$OPTARG;;
  esac
done

if [[ "$rebuild_node" =~ ^ncn-w ]]; then
  echo "Draining $rebuild_node"
  ssh ncn-m002 "kubectl drain --ignore-daemonsets --delete-local-data $rebuild_node"
  echo "sleeping 10 second...zzz.."
  sleep 10
  echo "Removing $rebuild_node from cluster"
  ssh ncn-m002 "kubectl delete node $rebuild_node"
fi

echo "Deleting server $rebuild_node"
openstack server delete $rebuild_node
echo "sleeping 10 second...zzz.."
sleep 10
echo "Deleting volume $rebuild_node"
openstack volume delete $rebuild_node

echo "Removing ncn ips from /etc/hosts"
sed -i -e '/DELETE_BELOW/q0' /etc/hosts

echo "Creating boot volumes for node ${rebuild_node}"
openstack volume create --size 45 --type RBD --snapshot k8s-1.19-gold  --bootable $rebuild_node

for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node" >> hosts; done

counter=1
until [ $counter -eq 0 ]
do
 counter=0
 echo "Checking status of boot volumes"
 for vol in $(openstack volume list -f json | jq -r '.[]| select(.Name|contains ("ncn-"))|.ID')
  do
    status=$(openstack volume show $vol -f json|jq -r .status)
    if [ "$status" != "available" ] && [ "$status" != "in-use" ]
    then
    counter=+1
    echo "Status of volume $vol is: $status"
    fi
  done
done

# use to get volume and server names
echo "sleeping 20 second...zzz.."
sleep 20

echo "Creating vms for K8S"
openstack server create  --flavor highcpu.4  --key-name craystack --user-data init.sh  --volume $rebuild_node --network Cray_Network --file /etc/hosts=hosts $rebuild_node

cp /var/www/ephemeral/configs/data.orig /var/www/ephemeral/configs/data.json
for node in $(openstack server list -f json| jq -r .[].Name|egrep -i 'ncn-')
do
 ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 echo $ip
 echo $node
 while [ -z "$ip" ]; do
    echo "Waiting for ip to get assigned"
    sleep 2
    ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 done

 until ping -c1 "$ip" 2>&1 >/dev/null; do echo "Waiting for $ip to have a mac address"; sleep 2; done
 mac="$(ip -r -br n show to $ip|awk '{print $5}')"
 echo "$ip $node $node.nmn" >> /etc/hosts
 sed -i -e "s/mac-$node/$mac/" /var/www/ephemeral/configs/data.json
done

echo "Restarting dnsmasq and basecamp"
systemctl restart dnsmasq.service
podman restart basecamp
