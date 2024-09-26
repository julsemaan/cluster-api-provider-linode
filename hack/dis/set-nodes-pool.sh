#!/bin/bash

set -o nounset -o pipefail -o errexit

scratch=$(mktemp)

set_cilium_node_pool() {
  node="$1"
  range="$2"

#  cat > $scratch <<EOF
#metadata:
#  annotations:
#    linode-pod-cidr: ${range}0/24
#spec:
#  ipam:
#    podCIDRs:
#    - ${range}0/24
#    pool:
#EOF
#  for i in {1..250}; do
#    echo "      $range$i: {}" >> $scratch
#  done
#  kubectl patch --type=merge --patch-file $scratch ciliumnode $node

  cat > $scratch <<EOF
  spec:
    podCIDR: ${range}0/24
    podCIDRs:
    - ${range}0/24
EOF
  kubectl patch --type=merge --patch-file $scratch node $node
}

db=$base_range.pod-pools.txt
touch $db
readarray -t lines < $db

declare -A ary=()

for line in "${lines[@]}"; do
   key=${line%%=*}
   value=${line#*=}
   ary[$key]=$value  ## Or simply ary[${line%%=*}]=${line#*=}
done

#echo ${#ary[@]}
idx=10
if test ${#ary[@]}; then
  idx=$((${#ary[@]} + idx))
fi
test ${ary[test]+_} && echo yes || echo no

while read line
do
  if test ${ary[$line]+_}; then
    echo "Setting range ${ary[$line]} for $line"
  else
    range="$base_range.$idx."
    echo "Adding range $range for $line"
    idx=$((idx + 1))
    ary[$line]=$range
  fi
  set_cilium_node_pool $line ${ary[$line]}
done <<< "$(kubectl get nodes -ltopology.linode.com/region=$region --no-headers | awk '{print $1}')"

: > $db
for i in "${!ary[@]}"
do
  echo "$i=${ary[$i]}" >> $db
done
