#!/bin/bash

for node in $(openstack server list -f json|jq -r '.[]|select((.Status="ACTIVE") and (.Name|startswith("ncn")))|.Name')
do
  echo "Deleting $node"
  openstack server delete $node
done

until [ $(openstack server list -f json|jq -r '.[]|select((.Status="ACTIVE") and (.Name|startswith("ncn")))|.Name'|wc -l) -eq 0 ]
do
  echo "Sleeping 20 seconds waiting for instances to be deleted"
  sleep 20
done

echo "Sleeping 30 seconds to hopefully avoid stuck volumes"
sleep 30

for boot_vol in $(openstack volume list -f json|jq -r '.[]|select(.Name | startswith("ncn"))|.ID')
do
  echo "Deleting boot volume $boot_vol"
  openstack volume delete $boot_vol
  echo "Sleeping 20 seconds waiting for volume to be deleted"
  sleep 20
done

for osd in $(openstack volume list -f json|jq -r '.[]|select(.Name | startswith("osd"))|.ID')
do
  echo "Deleteing osd $osd"
  openstack volume delete $osd
  echo "Sleeping 20 seconds waiting for volume to be deleted"
  sleep 20
done
