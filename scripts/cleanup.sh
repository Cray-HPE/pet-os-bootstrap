#!/bin/bash

for num in 1 2 3
do
  echo "Deleting server ncn-m00$num"
  openstack server delete ncn-m00$num

  echo "Deleting server ncn-w00$num"
  openstack server delete ncn-w00$num

  echo "Deleting server ncn-s00$num"
  openstack server delete ncn-s00$num

  echo "Deleting volume ncn-m00$num"
  openstack volume delete ncn-m00$num

  echo "Deleting volume ncn-w00$num"
  openstack volume delete ncn-w00$num

  echo "Deleting volume ncn-s00$num"
  openstack volume delete ncn-s00$num

  echo "Deleting volume osd.$num"
  openstack volume delete osd.$num
done
