# Create Volume

# I think we need to build something in that makes either k8s or ceph optional.
# they could technically build mercury using this as well.
# below code to test
while getopts k:c:a: stack
do
  case "${stack}" in
          k) k8s=$OPTARG;;
          c) ceph=$OPTARG;;
          a) all=$OPTARG;;
  esac
done

# Just here for sanity.  can remove shortly

echo "k8s $k8s"
echo "ceph $ceph"
echo "all $all"

if  [ "$ceph" = "true" ] || [ "$all" = "true" ]
then
  echo "Creating boot and OSD volumes for CEPH"
  for num in 1 2 3
  do
   openstack volume create --size 25 --type RBD  osd.$num
   openstack volume create --size 25 --type RBD --bootable --snapshot 1.4.ceph-gold ncn-s00$num
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
  echo "Creating boot volumes for K8S"
  for num in 1 2 3
  do
    openstack volume create --size 45 --type RBD --snapshot 1.4.k8s-gold  --bootable ncn-m00$num
    openstack volume create --size 45 --type RBD --snapshot 1.4.k8s-gold  --bootable ncn-w00$num
  done
fi


for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node" >> hosts; done



# Getting status of openstack volumes
# Change to a while or until

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
 for node in 1 2 3
  do
   openstack server create  --flavor highmem.2  --key-name  cdelatte --user-data init.sh  --volume ncn-s00$node --network Cray_Network  --file /etc/hosts=hosts ncn-s00$node
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
 echo "Creating vms for K8S"
 for node in 1 2 3
  do
   openstack server create  --flavor standard.2  --key-name  cdelatte --user-data init.sh  --volume ncn-m00$node --network Cray_Network  --file /etc/hosts=hosts ncn-m00$node
   openstack server create  --flavor highcpu.4  --key-name  cdelatte --user-data init.sh  --volume ncn-w00$node --network Cray_Network  --file /etc/hosts=hosts ncn-w00$node
  done
fi

# put conditional here based off status
#openstack server list -f json |jq '.[]| {Name, Status}'
echo "Sleeping for 20 seconds ...ZZZ..."
sleep 20
for vol in 1 2 3
 do
  openstack server add volume ncn-s00$vol osd.$vol
done
# For hosts file/dnsmasq

for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node"; done
