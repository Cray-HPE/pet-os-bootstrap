#!/bin/bash

first_master=ncn-m002
workers=$(pdsh -w $first_master "kubectl get nodes | grep ncn-w" | awk '{print $2}')

for worker in $workers; do
  ./upgrade-k8s-node.sh -n $worker
  state=$(pdsh -w $first_master "kubectl get nodes | grep $worker" 2>&1 | awk '{print $3}')
  cnt=0
  until [ "$state" == "Ready" ]; do
     echo "Waiting for $worker to become 'Ready'"
     sleep 5
     cnt=+1
     if [ "$cnt" -ge 60 ]; then
       echo "ERROR: $worker isn't ready after waiting 5 minutes -- aborting!"
       exit 1
     fi
     state=$(pdsh -w $first_master "kubectl get nodes | grep $worker" 2>&1 | awk '{print $3}')
  done
  echo "SUCCESS: $worker is now in a ready state"
done
