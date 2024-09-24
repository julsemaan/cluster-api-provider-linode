
# How to use this

Run everything from within `hack/dis`
```
cd hack/dis
```

Deploy the cluster
```
export LINODE_TOKEN=<your token>
$ cat test-cluster.yaml | envsubst | k apply -f -
```

Wait until the cluster and all nodes are ready
```
$ k get machines
```

Open a new shell and setup kubectl to communicate with your new cluster
```
$ clusterctl get kubeconfig test-cluster > kubeconfig.yaml
$ export KUBECONFIG=kubeconfig.yaml
$ k get nodes
NAME                                 STATUS   ROLES           AGE     VERSION
test-cluster-control-plane-5zdj6     Ready    control-plane   14m     v1.29.1
test-cluster-control-plane-6q4xk     Ready    control-plane   8m47s   v1.29.1
test-cluster-control-plane-cr8np     Ready    control-plane   11m     v1.29.1
test-cluster-md-0-psgzt-l7xk4        Ready    <none>          12m     v1.29.1
test-cluster-md-0-psgzt-lmx9p        Ready    <none>          11m     v1.29.1
test-cluster-md-remote-kq5v8-n8dtf   Ready    <none>          11m     v1.29.1
test-cluster-md-remote-kq5v8-rfm57   Ready    <none>          11m     v1.29.1
```

Get VPC ranges in place
```
$ bash set-vpc-ranges.sh
```

Validate that the VPCs are properly setup

 - There are 2 VPCs (test-cluster and test-cluster-remote)
 - Both should have the linodes in them
 - All linodes in the VPCs have an assigned IP range on top of their individual assigned IP

Get the NodeBalancer configured to handle konnectivity-server traffic
```
$ bash setup-konnectivity-nb.sh
```

Setup konnectivity on the cluster
```
$ k apply -f konnectivity-agent.yaml
$ k apply -f konnectivity-rbac.yaml
$ bash setup-konnectivity.sh 
```

Run a sample workload and the script will exec into each of the pod (proving konnectivity is working)
```
$ bash exec-pods-ds.yaml
```
