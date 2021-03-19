#!/bin/bash

kubeadm token create --print-join-command > /etc/cray/kubernetes/join-command 2>/dev/null
echo "$(cat /etc/cray/kubernetes/join-command) --control-plane --certificate-key $(cat /etc/cray/kubernetes/certificate-key)" > /etc/cray/kubernetes/join-command-control-plane
