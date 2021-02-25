# Create Volume
> hosts

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


for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node" >> hosts; done

for num in 1 2 3
do
  openstack volume create --size 25 --type RBD  osd.$num
  openstack volume create --size 25 --type RBD --image 1.4.storage-ceph-0.0.30.qcow2 --bootable ncn-s00$num
  openstack volume create --size 25 --type RBD --image 1.4.kubernetes-0.0.35.qcow2 --bootable ncn-m00$num
  openstack volume create --size 25 --type RBD --image 1.4.kubernetes-0.0.35.qcow2 --bootable ncn-w00$num
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
  openstack -v server create  --flavor highmem.2  --key-name  cdelatte --user-data init.sh  --volume ncn-m00$node --network Cray_Network  --file /etc/hosts=hosts ncn-m00$node
  openstack -v server create  --flavor highmem.2  --key-name  cdelatte --user-data init.sh  --volume ncn-w00$node --network Cray_Network  --file /etc/hosts=hosts ncn-w00$node
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
# For hosts file/dnsmasq

for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node"; don
