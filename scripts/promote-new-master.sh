#!/bin/bash

#ip=$(dig +short $(hostname))
kubeadm token create --print-join-command > /etc/cray/kubernetes/join-command 2>/dev/null
#
# Need to scp this instead of re-generating
#
#kubeadm alpha certs certificate-key > /etc/cray/kubernetes/certificate-key
#chmod 0600 /etc/cray/kubernetes/certificate-key
#sed -i "s/\(.*https:\/\/\).*\(:6443\)/\1$ip\2/" /etc/kubernetes/admin.conf
echo "$(cat /etc/cray/kubernetes/join-command) --control-plane --certificate-key $(cat /etc/cray/kubernetes/certificate-key)" > /etc/cray/kubernetes/join-command-control-plane
#sed -i "s/\(.*\) .*:6443 \(.*\)/\1 $ip:6443 \2/" /etc/cray/kubernetes/join-command*
