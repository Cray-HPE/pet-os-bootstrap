# Create Volume

# I think we need to build something in that makes either k8s or ceph optional.
# they could technically build mercury using this as well.
# below code to test
while getopts k:c:a:i: stack
do
  case "${stack}" in
          k) k8s=$OPTARG;;
          i) sshkey=$OPTARG;;
          c) ceph=$OPTARG;;
          a) all=$OPTARG;;
  esac
done

echo "Removing ncn ips from /etc/hosts"
sed -i -e '/DELETE_BELOW/q0' /etc/hosts

# Just here for sanity.  can remove shortly

echo "k8s $k8s"
echo "ceph $ceph"
echo "all $all"
echo "sshkey $sshkey"

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
   openstack server create  --flavor highmem.2  --key-name  $sshkey --user-data init.sh  --volume ncn-s00$node --network Cray_Network --network PET_NET --file /etc/hosts=hosts ncn-s00$node
  done
fi

if [ "$k8s" = "true" ] || [ "$all" = "true" ]
then
 echo "Creating vms for K8S"
 for node in 1 2 3
  do
   openstack server create  --flavor standard.2  --key-name  $sshkey --user-data init.sh  --volume ncn-m00$node --network Cray_Network  --network PET_NET --file /etc/hosts=hosts ncn-m00$node
   openstack server create  --flavor highcpu.4  --key-name  $sshkey --user-data init.sh  --volume ncn-w00$node --network Cray_Network --network PET_NET --file /etc/hosts=hosts ncn-w00$node
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
# For hosts file/dnsmasq

#for node in $(openstack server list -f json| jq -r .[].Name); do  echo "$(openstack server show -f json $node|jq -r .addresses|cut -d = -f2) $node $node.nmn"; done
for node in $(openstack server list -f json| jq -r .[].Name|egrep -i 'ncn-')
do
 ip="$(openstack server show -f json $node|jq -r .addresses|cut -d ';' -f1|cut -d = -f2)"
 ping -c1 "$ip" 2>&1 >/dev/null
 mac="$(ip -r -br n show to $ip|awk '{print $5}')"
 echo "$ip $node $node.nmn" >> /etc/hosts
 sed -i -e "s/mac-$node/$mac/" /var/www/ephemeral/configs/data.json
done

echo "Restarting dnsmasq and basecamp"
systemctl restart dnsmasq.service
podman restart basecamp

# Put in scp for resolv.conf
# should we automate adding in the nameserver?  pit is supposed to stay around
