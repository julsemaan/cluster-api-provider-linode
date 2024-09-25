#!/bin/bash

set -o nounset -o pipefail -o errexit

OPTS="--text --no-headers"

cluster_name=$(kubectl get nodes -ocustom-columns=cluster-name:".metadata.annotations.cluster\.x-k8s\.io/cluster-name" --no-headers | head -1)

nb_id=$(linode-cli $OPTS nodebalancers ls --label=$cluster_name --format=id)

if linode-cli nodebalancers configs-list $nb_id --text --no-headers | grep -v 6443; then
  linode-cli nodebalancers configs-list $nb_id --text --no-headers | grep -v 6443 | awk '{ print $1 }' |
  while read line
  do
    linode-cli nodebalancers config-delete $nb_id $line
  done
fi


for port in 8132 8133 8134; do
  echo "Configuring port $port"
  config_id=$(linode-cli $OPTS nodebalancers config-create $nb_id --port $port --algorithm roundrobin --stickiness none --protocol tcp --format=id)

  kubectl get nodes -lnode-role.kubernetes.io/control-plane= -ocustom-columns=label:.metadata.name --no-headers |
  while read line
  do
    label=$(echo $line | awk '{print $1}')
    linode_id=$(linode-cli $OPTS linodes ls --label $label --format=id)
    private_ipv4=$(linode-cli $OPTS linodes view $linode_id --format=ipv4 | awk '{print $2}')
    
    echo "Adding $label as backend for $port"

    linode-cli nodebalancers node-create \
    $nb_id $config_id \
    --address $private_ipv4:$port \
    --label $label \
    --mode accept
  done
done
