#!/bin/bash

kubectl apply -f ds.yaml

kubectl rollout status daemonset test

toping=$(kubectl get pods -oyaml | grep podIP: | egrep -o '10\..+')

for ip in $toping; do
  echo ===================
  kubectl get pods -lname=test --no-headers | awk '{print $1}' | xargs -I{} kubectl exec {} -- bash -c 'echo -n "ping from " && hostname && ping -c 1 '$ip
done
