#!/bin/bash

#!/bin/bash

set -o nounset -o pipefail -o errexit

known_hosts_tmp=$(mktemp)

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp -n"
SCP_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=$known_hosts_tmp"

scratch=$(mktemp)
peers_scratch=$(mktemp)

range="10.37.0"
mask=24
idx=1
while read line
do
  #ssh $SSH_OPTS $external_ip mkdir -p /etc/kubernetes/admin/
  pvt_key=$(wg genkey)
  pub_key=$(echo $pvt_key | wg pubkey)
  wg_ip="$range.$idx"
  idx=$((idx + 1))
  podcidr=$(kubectl get node $line -ocustom-columns=cidr:.spec.podCIDR --no-headers)
  ext_ip=$(kubectl get node $line --no-headers -owide | awk '{print $7}')

  info="$line $pvt_key $pub_key $wg_ip $podcidr $ext_ip"

  echo $pvt_key > $scratch
  scp $SCP_OPTS $scratch $ext_ip:/etc/wireguard/privatekey

  ssh $SSH_OPTS $ext_ip apt install -y wireguard-tools
  ssh $SSH_OPTS $ext_ip ip link del dev wg0 || true
  ssh $SSH_OPTS $ext_ip ip link add dev wg0 type wireguard
  ssh $SSH_OPTS $ext_ip ip address add dev wg0 $wg_ip/$mask
  ssh $SSH_OPTS $ext_ip wg set wg0 listen-port 8172 private-key /etc/wireguard/privatekey
  ssh $SSH_OPTS $ext_ip ip link set up dev wg0

  echo $info >> $peers_scratch
done <<< "$(kubectl get nodes --no-headers | awk '{print $1}')"

while read p; do
  ext_ip=$(echo $p | awk '{print $6}')
  while read p; do
    pub_key=$(echo $p | awk '{print $3}')
    wg_ip=$(echo $p | awk '{print $4}')
    podcidr=$(echo $p | awk '{print $5}')
    endpoint=$(echo $p | awk '{print $6}'):8172
    echo $pub_key $wg_ip $endpoint
    ssh $SSH_OPTS $ext_ip wg set wg0 peer $pub_key allowed-ips $wg_ip/32 allowed-ips $podcidr endpoint $endpoint
    ssh $SSH_OPTS $ext_ip ip route del $podcidr || true
    ssh $SSH_OPTS $ext_ip ip route add $podcidr via $wg_ip
  done <$peers_scratch
done <$peers_scratch

