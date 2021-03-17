#!/bin/bash

#
# FUNCTIONS
#
function get_first_master() {
  first_master=$(cat /var/www/ephemeral/configs/data.json | jq -r '.Global."meta-data"."first-master-hostname"')
  echo $first_master
}

function wait_for_node() {
  local first_master=$1
  local node=$2
  state=$(pdsh -w $first_master "kubectl get nodes | grep $node" 2>&1 | awk '{print $3}')
  cnt=0
  until [ "$state" == "Ready" ]; do
     echo "Waiting for $node to become 'Ready'"
     sleep 5
     cnt=+1
     if [ "$cnt" -ge 60 ]; then
       echo "ERROR: $node isn't ready after waiting 5 minutes -- aborting!"
       exit 1
     fi
     state=$(pdsh -w $first_master "kubectl get nodes | grep $node" 2>&1 | awk '{print $3}')
  done
  echo "SUCCESS: $node is now in a ready state"
}

#
# EXECUTION
#
first_master=$(get_first_master)
masters=$(pdsh -w $first_master "kubectl get nodes | grep ncn-m" | awk '{print $2}')
for master in $masters; do
  if [ "$master" == "$first_master" ]; then
     echo "BRAD: skipping upgrade of $first_master for now"
     continue
  fi
  ./upgrade-k8s-node.sh -n $master -f $first_master
  wait_for_node $first_master $master
done

workers=$(pdsh -w $first_master "kubectl get nodes | grep ncn-w" | awk '{print $2}')
for worker in $workers; do
  ./upgrade-k8s-node.sh -n $worker -f $first_master
  wait_for_node $first_master $worker
done
