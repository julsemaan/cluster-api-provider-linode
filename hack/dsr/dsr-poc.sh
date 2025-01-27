#!/bin/bash

#linode-cli linodes create --region us-ord --type g6-standard-2 --authorized_users=jusemaa-akamai
#
#linode-cli networking v6-range-create --prefix_length=64 --linode_id=70887238
#
#linode-cli networking ip-share --ips=2600:3c06:e001:6db:: --linode_id=70887238
#linode-cli networking ip-share --ips=2600:3c06:e001:6db:: --linode_id=70883540
#
KV_DIR=.dsr-poc
KV_LOAD_BAL_LIN_ID="load_bal_lin_id"
KV_V6_VIP_RANGE="v6_vip_range"

ensure_kv_dir() {
  mkdir -p $KV_DIR
}

kv_exists() {
  [ -f $KV_DIR/$1 ]
}

kv_get() {
  ensure_kv_dir
  cat $KV_DIR/$1 2>/dev/null
}

kv_write() {
  ensure_kv_dir
  echo -n $2 > $KV_DIR/$1
}

kv_delete() {
  ensure_kv_dir
  rm -f $KV_DIR/$1
}

deploy_load_bal() {
  if kv_exists $KV_LOAD_BAL_LIN_ID ; then
    echo "Already have a load-balancer, skipping"
    return 0
  fi    
  
  lin_id=$(linode-cli linodes create --label=dsr-poc-lb-`date +%s` --region us-ord --type g6-standard-2 --authorized_users=jusemaa-akamai --pretty  | jq -r .[0].id)
  kv_write $KV_LOAD_BAL_LIN_ID $lin_id 

  v6_range=$(linode-cli networking v6-range-create --prefix_length=64 --linode_id=$lin_id --pretty | jq -r .[0].range)
  kv_write $KV_V6_VIP_RANGE $v6_range

  v6_ip=$(echo -n $v6_range | sed 's|/[0-9]*$||') 

  linode-cli networking ip-share --ips=$v6_ip --linode_id=$lin_id
}

deploy_cluster() {
  cat hack/dsr/test-cluster-xdp.yaml | envsubst | kubectl apply -f-

  until [ $(kubectl get machines --no-headers | wc -l) -ne 0 ]; do
    echo "Waiting for machines to appear"
    sleep 5
  done

  until [ $(kubectl get machine -l'cluster.x-k8s.io/control-plane' --no-headers | awk '{print $5}' | uniq) == 'Running' ]; do
    echo "Waiting for all control-plane machines to be 'Running'"
    sleep 5
  done

  until [ $(kubectl get machine -l'!cluster.x-k8s.io/control-plane' --no-headers | awk '{print $5}' | uniq) == 'Running' ]; do
    echo "Waiting for all worker machines to be 'Running'"
    sleep 5
  done

  echo "All worker nodes are 'Running'"
  
  return 0
}

share_ips() {

  return 0
}

teardown() {
  linode-cli linodes delete $(kv_get $KV_LOAD_BAL_LIN_ID) 
  kv_delete $KV_LOAD_BAL_LIN_ID

  return 0
}

deploy_load_bal
deploy_cluster

echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++=
echo "Completed setup, the PoC should now be running."
read -p "Run teardown (selecting no will exit the script and leave resources online)? (y/N)" -n 1 -r ; echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  teardown
fi

