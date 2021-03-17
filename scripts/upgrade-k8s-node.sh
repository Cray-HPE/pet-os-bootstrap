#!/bin/bash

while getopts n: options
do
  case "${options}" in
          n) rebuild_node=$OPTARG;;
  esac
done

#
# TODO: get 'first' node and use that below -- assuming ncn-m002 for now
#
first_master=ncn-m002

if [[ "$rebuild_node" =~ ^ncn-w ]]; then
  echo "Draining $rebuild_node"
  ssh $first_master "kubectl drain --ignore-daemonsets --delete-local-data $rebuild_node"
  echo "sleeping 10 second...zzz.."
  sleep 10
  echo "Removing $rebuild_node from cluster"
  ssh $first_master "kubectl delete node $rebuild_node"

elif [[ "$rebuild_node" =~ ^ncn-m ]]; then

  if [[ "$rebuild_node" == "$first_master"  ]]; then
    echo "this is first master -- do special things" 
  else
    echo "Stopping etcd on $rebuild_node"
    ssh $rebuild_node "systemctl stop etcd.service"
    echo "Removing $rebuild_node from etcd cluster"
    ssh $first_master "etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/ca.crt  --key=/etc/kubernetes/pki/etcd/ca.key --endpoints=localhost:2379 member remove $(etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/ca.crt  --key=/etc/kubernetes/pki/etcd/ca.key --endpoints=localhost:2379 member list | grep $rebuild_node | cut -d , -f1)"
    echo "Removing $rebuild_node from cluster"
    ssh $first_master "kubectl delete node $rebuild_node"
  fi
fi

if [[ "$rebuild_node" =~ ^ncn-m ]]; then
  exit 0
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
 while [ -z "$ip" ]; do
    echo "Waiting for ip to get assigned for $node"
    sleep 2
    ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 done

 until ping -c1 "$ip" 2>&1 >/dev/null; do echo "Waiting for node ${node}'s ip (${ip}) to have a mac address"; sleep 2; done
 mac="$(ip -r -br n show to $ip|awk '{print $5}')"
 echo "Node $node has ip: $ip and mac: $mac"
 echo "$ip $node $node.nmn" >> /etc/hosts
 sed -i -e "s/mac-$node/$mac/" /var/www/ephemeral/configs/data.json
done

echo "Restarting dnsmasq and basecamp"
systemctl restart dnsmasq.service
podman restart basecamp
