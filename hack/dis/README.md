
# How to use this

If using any distributed sites, delete the mutating webhook
```
$ k delete validatingwebhookconfigurations.admissionregistration.k8s.io capl-validating-webhook-configuration
```

Run everything from within `hack/dis`
```
$ cd hack/dis
```

Deploy the cluster
```
$ export LINODE_TOKEN=<your token>
$ cat test-cluster.yaml | envsubst | k apply -f -
```

Wait until the cluster and wait until one control-plane is Provisioning
```
$ k get machines | grep control-plane
test-cluster-control-plane-wckbl     test-cluster                           Provisioning   73s    v1.29.1
```

Open a new shell and setup kubectl to communicate with your new cluster (it may take a few minutes for the apiserver to start)

You'll have to wait until the first control-plane node shows as Ready
```
$ clusterctl get kubeconfig test-cluster > kubeconfig.yaml
$ export KUBECONFIG=kubeconfig.yaml
$ k get nodes
NAME                                 STATUS   ROLES           AGE     VERSION
test-cluster-control-plane-wckbl     Ready    control-plane   8m47s   v1.29.1
```

Get pod CIDRs in place in cilium for the current control-plane node

```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
```

Wait for the other nodes to boot up and join (workers will appear and two more control-plane node). This will take ~5 minutes

```
$ k get nodes
NAME                                 STATUS   ROLES           AGE   VERSION
test-cluster-control-plane-8ntzf     Ready    control-plane   13m   v1.29.1
test-cluster-control-plane-jnlw6     Ready    control-plane   10m   v1.29.1
test-cluster-control-plane-wckbl     Ready    control-plane   19m   v1.29.1
test-cluster-md-0-5r856-2p5g2        Ready    <none>          15m   v1.29.1
test-cluster-md-0-5r856-gbslx        Ready    <none>          15m   v1.29.1
test-cluster-md-remote-666jj-bsjvn   Ready    <none>          15m   v1.29.1
test-cluster-md-remote-666jj-tr8cr   Ready    <none>          15m   v1.29.1
```

Now, get all the pod CIDRs in place
```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
$ region=us-mia base_range=10.42 bash set-pod-cidrs.sh
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
$ bash setup-konnectivity.sh 
```

Wait a couple of minutes for kubelet to restart all apiserver pods so that they pickup the new konnectivity config

Install a sample workload that runs on all nodes and the script will exec into each pod (proving konnectivity is working)
```
$ bash exec-pods-ds.yaml
```

Now, we can add peering capabilities to our VPCs through Wireguard by having pod CIDRs that are in different DCs go through a wg mesh

To setup the Wireguard mesh and routes
```
$ bash setup-wireguard.sh 
```

When you're done having fun:
```
$ rm *.pod-pools.txt
$ unset KUBECONFIG
$ k delete -f test-cluster.yaml
```
