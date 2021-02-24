# Create Volume
> hosts

for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node" >> hosts; done

for num in 1 2 3
 do
  openstack volume create --size 25 --type RBD  osd.$num
  openstack volume create --size 25 --type RBD --image 1.4.storage-ceph-0.0.30.qcow2 --bootable ncn-s00$num
 done


# Getting status of openstack volumes
# Change to a while or until

counter=1
until [ $counter -eq 0 ]
do
 counter=0
 for vol in $(openstack volume list -f json|jq -r .[].ID)
  do
    if [ "$(openstack volume show $vol -f json|jq -r .status)" != "available" ]
    then
    counter=+1
    fi
  done
done

# use to get volume and server names
echo "sleeping 60 second...zzz.."
sleep 60

for node in 1 2 3
 do
  openstack -v server create  --flavor highmem.2  --key-name  cdelatte --user-data init.sh  --volume ncn-s00$node --network Cray_Network  --file /etc/hosts=hosts ncn-s00$node
 done
#openstack server add volume ncn-s003 osd.3

# put conditional here based off status
#openstack server list -f json |jq '.[]| {Name, Status}'
echo "Sleeping for 2 mins...ZZZ..."
sleep 120
for vol in 1 2 3
 do
  openstack server add volume ncn-s00$vol osd.$vol
 done
For hosts file/dnsmasq

for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node"; done
