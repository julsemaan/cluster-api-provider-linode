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
KV_V4_VIP="v4_vip"
KV_V6_VIP="v6_vip"
KV_V6_VIP_RANGE="v6_vip_range"
KV_V6_VIP_RANGE_IP="v6_vip_range_ip"

known_hosts_tmp=$(mktemp)
SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp -n"
SCP_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp"

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

kv_flush() {
  ensure_kv_dir
  find $KV_DIR -type f -delete
}

deploy_load_bal() {
  if ! kv_exists $KV_LOAD_BAL_LIN_ID ; then
    lin_id=$(linode-cli linodes create --label=dsr-poc-lb-`date +%s` --region us-ord --type g6-standard-2 --authorized_users=jusemaa-akamai --pretty --image=linode/ubuntu22.04 --root_pass=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo) | jq -r .[0].id)
    kv_write $KV_LOAD_BAL_LIN_ID $lin_id 
    echo "Created load-balancer linode $lin_id"
  fi    

  lin_id=$(kv_get $KV_LOAD_BAL_LIN_ID)
  
  v4_vip=$(linode-cli linodes view $lin_id --pretty | jq -r .[0].ipv4.[0])
  kv_write $KV_V4_VIP $v4_vip
  echo "Fetched v4 VIP $v4_vip"

  if ! kv_exists $KV_V6_VIP_RANGE; then
    v6_range=$(linode-cli networking v6-range-create --prefix_length=64 --linode_id=$lin_id --pretty | jq -r .[0].range)
    kv_write $KV_V6_VIP_RANGE $v6_range
    echo "Created v6 range $v6_range"
  fi

  v6_range=$(kv_get $KV_V6_VIP_RANGE)

  v6_range_ip=$(echo -n $v6_range | sed 's|/[0-9]*$||') 
  kv_write $KV_V6_VIP_RANGE_IP $v6_range_ip
  kv_write $KV_V6_VIP $v6_range_ip"1"

  linode-cli networking ip-share --ips=$v6_range_ip --linode_id=$lin_id
  echo "Added v6 range $v6_range_ip to $lin_id"
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
  v4_vip=$(kv_get $KV_V4_VIP)
  v6_range_ip=$(kv_get $KV_V6_VIP_RANGE_IP)
  for workerLinodeId in $(kubectl get linodemachine -l'!cluster.x-k8s.io/control-plane' -ocustom-columns=cidr:.spec.providerID --no-headers | sed 's|linode://||'); do
    linode-cli networking ip-share --ips=$v4_vip --linode_id=$workerLinodeId
    linode-cli networking ip-share --ips=$v6_range_ip --linode_id=$workerLinodeId
    echo "Shared $v4_vip and $v6_range_ip with $workerLinodeId"
  done
}

setup_httpbin() {
  kubeconfig=$(mktemp)
  clusterctl get kubeconfig test-cluster-xdp > $kubeconfig
  kubectl --kubeconfig=$kubeconfig apply -f hack/dsr/httpbin-v6.yaml
  kubectl --kubeconfig=$kubeconfig patch svc httpbin2 --subresource='status' \
    -p "{\"status\":{\"loadBalancer\":{\"ingress\":[{\"ip\":\"$(kv_get $KV_V4_VIP)\",\"ipMode\":\"VIP\"}, {\"ip\":\"$(kv_get $KV_V6_VIP)\",\"ipMode\":\"VIP\"}]}}}"
  return 0
}

setup_ipvsadm() {
  lin_id=$(kv_get $KV_LOAD_BAL_LIN_ID)

  until [ $(linode-cli linodes view 70893758 --pretty | jq -r .[0].status) == "running" ]; do
    echo "Waiting for $lin_id to boot"
  done

  v4_vip=$(kv_get $KV_V4_VIP)
  echo Installing ipvsadm on $v4_vip
  ssh $SSH_OPTS $v4_vip apt update 
  ssh $SSH_OPTS $v4_vip apt install ipvsadm 
}

teardown() {
  lb_lin_id=$(kv_get $KV_LOAD_BAL_LIN_ID)
  linode-cli linodes delete $lb_lin_id 
  echo "Deleted load-balancer linode $lb_lin_id"

  v6_vip_range_ip=$(kv_get $KV_V6_VIP_RANGE_IP)
  linode-cli networking v6-range-delete $v6_vip_range_ip 
  echo "Deleted v6 range $v6_vip_range_ip"

  kv_flush

  echo "Completed teardown"

  return 0
}

deploy_load_bal
deploy_cluster
share_ips
setup_httpbin
setup_ipvsadm

echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++=
echo "Completed setup, the PoC should now be running."
read -p "Run teardown (selecting no will exit the script and leave resources online)? (y/N)" -n 1 -r ; echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  teardown
else
  echo "Skipping teardown"
fi

