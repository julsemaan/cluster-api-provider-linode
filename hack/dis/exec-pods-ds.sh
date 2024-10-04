#!/bin/bash

kubectl apply -f ds.yaml

kubectl rollout status daemonset test

kubectl get pods -lname=test --no-headers | awk '{print $1}' | xargs -I{} kubectl exec {} -- bash -c 'echo -n "hello from " && hostname'
