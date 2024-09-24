#!/bin/bash

set -o nounset -o pipefail -o errexit

OPTS="--text --no-headers"

set_vpc_ip_range() {
  label="$1"
  range="$2"
  linode_id=$(linode-cli $OPTS linodes ls --label $label --format=id)
  config_id=$(linode-cli $OPTS linodes configs-list $linode_id --format=id)
  interface_id=$(linode-cli $OPTS linodes config-interfaces-list $linode_id $config_id --format=id,purpose | grep vpc | awk '{ print $1 }')

  echo "Setting $range on $label"
  linode-cli linodes config-interface-update $linode_id $config_id $interface_id --ip_range=$range
}

label="test-cluster-md-0-h2bpj-brwr9"
range="10.192.4.0/24"

kubectl get nodes -ocustom-columns=label:.metadata.name,cidr:.spec.podCIDR --no-headers |
while read line
do
  label=$(echo $line | awk '{print $1}')
  range=$(echo $line | awk '{print $2}')
  set_vpc_ip_range $label $range
done

