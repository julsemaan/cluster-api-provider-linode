#!/bin/bash

set -o nounset -o pipefail -o errexit

known_hosts_tmp=$(mktemp)

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp -n"
SCP_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp"
OPTS="--text --no-headers"

setup_konnectivity() {
  label="$1"
  external_ip="$2"

  set -x

  ssh $SSH_OPTS $external_ip mkdir -p /etc/kubernetes/admin/
  scp $SCP_OPTS egress-selector-configuration.yaml $external_ip:/etc/kubernetes/admin/egress-selector-configuration.yaml
  scp $SCP_OPTS setup-konnectivity-kubeconfig.sh $external_ip:/tmp/setup-konnectivity-kubeconfig.sh

  if ! [ -f /tmp/konnectivity-server.conf ]; then
    server=$(kubectl config view -o jsonpath='{.clusters..server}')
    ssh $SSH_OPTS $external_ip bash /tmp/setup-konnectivity-kubeconfig.sh $server
    scp $SCP_OPTS $external_ip:/etc/kubernetes/konnectivity-server.conf /tmp/konnectivity-server.conf
  else
    scp $SCP_OPTS /tmp/konnectivity-server.conf $external_ip:/etc/kubernetes/konnectivity-server.conf
  fi

  #ssh $SSH_OPTS $external_ip systemctl restart kubelet
  
  scp $SCP_OPTS konnectivity-server.yaml $external_ip:/etc/kubernetes/manifests/

  sed 's/MY_SERVER_IP/'$server'/' kube-apiserver.tpl > kube-apiserver.yaml
  scp $SCP_OPTS kube-apiserver.yaml $external_ip:/etc/kubernetes/manifests/

  set +x
}

rm -f /tmp/konnectivity-server.conf

server=$(kubectl config view -o jsonpath='{.clusters..server}' | egrep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
sed 's/MY_SERVER_IP/'$server'/' konnectivity-agent.tpl > konnectivity-agent.yaml 

kubectl apply -f konnectivity-agent.yaml
kubectl apply -f konnectivity-rbac.yaml

kubectl get nodes -lnode-role.kubernetes.io/control-plane= -owide --no-headers |
while read line
do
  label=$(echo $line | awk '{print $1}')
  external_ip=$(echo $line | awk '{print $7}')
  setup_konnectivity $label $external_ip
done

#kubectl delete pods -lk8s-app=konnectivity-server -n kube-system
#kubectl delete pods -lk8s-app=konnectivity-agent -n kube-system
