
# How to use this

NOTE: This PoC leverages a custom CCM built from here: https://github.com/julsemaan/linode-cloud-controller-manager/tree/feat/multi-vpc

NOTE: This PoC has a firewall in geo-cluster-core.yaml that has assumptions around which source IP can be used for SSH and deploying in specific DCs. Adjust to your needs.

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
$ cat hack/dis/geo-cluster-core.yaml | envsubst | k apply -f -
```

Wait until the cluster and wait until one control-plane is Provisioning
```
$ k get machines | grep control-plane
geo-cluster-core-control-plane-4lnfz      geo-cluster-core                            Provisioning   1s    v1.29.1
```

Open a new shell and setup kubectl to communicate with your new cluster (it may take a few minutes for the apiserver to start)

You'll have to wait until the first control-plane node shows as Ready
```
$ clusterctl get kubeconfig geo-cluster-core > kubeconfig.yaml
$ export KUBECONFIG=kubeconfig.yaml
$ k get nodes
NAME                                   STATUS   ROLES           AGE   VERSION
geo-cluster-core-control-plane-4lnfz   Ready    control-plane   34s   v1.29.1
```

Get pod CIDRs in place in cilium for the current control-plane node

```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
```

Wait for the other nodes to boot up and join (workers will appear and two more control-plane node). This will take ~5 minutes

```
$ k get nodes
NAME                                     STATUS   ROLES           AGE     VERSION
geo-cluster-core-control-plane-4lnfz     Ready    control-plane   12m     v1.29.1
geo-cluster-core-control-plane-8j7ns     Ready    control-plane   7m7s    v1.29.1
geo-cluster-core-control-plane-q6j84     Ready    control-plane   4m14s   v1.29.1
geo-cluster-core-md-0-cv7t8-47j2d        Ready    <none>          10m     v1.29.1
geo-cluster-core-md-0-cv7t8-zsl5d        Ready    <none>          8m54s   v1.29.1
geo-cluster-core-md-remote-2tj6m-dg5b8   Ready    <none>          10m     v1.29.1
geo-cluster-core-md-remote-2tj6m-phwj9   Ready    <none>          10m     v1.29.1
```

Now, get all the pod CIDRs in place
```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
$ region=it-mil base_range=10.42 bash set-pod-cidrs.sh
```

Get VPC ranges in place
```
$ bash set-vpc-ranges.sh
```

Validate that the VPCs are properly setup

 - There are 2 VPCs (geo-cluster-core and geo-cluster-core-remote)
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
$ bash exec-pods-ds.sh
```

Now, we can add peering capabilities to our VPCs through Wireguard by having pod CIDRs that are in different DCs go through a wg mesh

To setup the Wireguard mesh and routes
```
$ bash setup-wireguard.sh 
```

Install a sample workload that runs on all nodes and the script will exec into each pod and ping each other test pod in the cluster (proving pod-to-pod works across regions)
```
$ bash ping-pods-ds.sh
```

When you're done having fun:
```
$ rm *.pod-pools.txt
$ unset KUBECONFIG
$ k delete -f geo-cluster-core.yaml
```
