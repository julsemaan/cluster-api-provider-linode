#!/bin/bash

set -o nounset -o pipefail -o errexit

base_range="10.40"

db=$base_range.pod-pools.txt
touch $db
readarray -t lines < $db

declare -A ary

for line in "${lines[@]}"; do
   key=${line%%=*}
   value=${line#*=}
   ary[$key]=$value  ## Or simply ary[${line%%=*}]=${line#*=}
done

#echo ${#ary[@]}
idx=0
if test ${#ary[@]}; then
  idx=${#ary[@]}
fi
test ${ary[test]+_} && echo yes || echo no

while read line
do
  echo $line
  if test ${ary[$line]+_}; then
    echo ${ary[$line]}
  else
    cidr="$base_range.$idx.0"
    echo "Adding CIDR $cidr for $line"
    idx=$((idx + 1))
    ary[$line]=$cidr
  fi
done <<< "$(kubectl get nodes -ltopology.kubernetes.io/region=us-ord --no-headers | awk '{print $1}')"

: > $db
for i in "${!ary[@]}"
do
  echo "$i=${ary[$i]}" >> $db
done
