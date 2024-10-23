
# How to use this

NOTE: This PoC leverages a custom CCM built from here: https://github.com/julsemaan/linode-cloud-controller-manager/tree/feat/multi-vpc

NOTE: This PoC has a firewall in geo-cluster-gecko-gecko.yaml that has assumptions around which source IP can be used for SSH and deploying in specific DCs. Adjust to your needs.

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
$ cat geo-cluster-gecko-gecko.yaml | envsubst | k apply -f -
```

Wait until the cluster and wait until one control-plane is Provisioning
```
$ k get machines | grep control-plane
geo-cluster-gecko-control-plane-4lnfz      geo-cluster-gecko                            Provisioning   1s    v1.29.1
```

Open a new shell and setup kubectl to communicate with your new cluster (it may take a few minutes for the apiserver to start)

You'll have to wait until the first control-plane node shows as Ready
```
$ clusterctl get kubeconfig geo-cluster-gecko > kubeconfig.yaml
$ export KUBECONFIG=kubeconfig.yaml
$ k get nodes
NAME                                      STATUS     ROLES           AGE     VERSION
geo-cluster-gecko-control-plane-8pqj7     Ready      control-plane   3m31s   v1.29.1
```

Get pod CIDRs in place in cilium for the current control-plane node

```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
```

Wait for the other nodes to boot up and join (workers will appear and two more control-plane node). This will take ~5 minutes

```
$ k get nodes
NAME                                      STATUS   ROLES           AGE     VERSION
geo-cluster-gecko-control-plane-8pqj7     Ready    control-plane   12m     v1.29.1
geo-cluster-gecko-control-plane-l2tff     Ready    control-plane   5m53s   v1.29.1
geo-cluster-gecko-control-plane-zzskl     Ready    control-plane   3m11s   v1.29.1
geo-cluster-gecko-md-0-qxx72-j6nwp        Ready    <none>          8m39s   v1.29.1
geo-cluster-gecko-md-0-qxx72-s79bg        Ready    <none>          8m14s   v1.29.1
geo-cluster-gecko-md-remote-4msfw-qs752   Ready    <none>          10m     v1.29.1
geo-cluster-gecko-md-remote-4msfw-wwt99   Ready    <none>          9m42s   v1.29.1
```

Now, get all the pod CIDRs in place
```
$ region=us-ord base_range=10.41 bash set-pod-cidrs.sh
$ region=fr-mrs-1 base_range=10.42 bash set-pod-cidrs.sh
$ region=za-jnb-1 base_range=10.43 bash set-pod-cidrs.sh
```

Get VPC ranges in place (only ORD because the gecko site doesn't have VPC)
```
$ region=us-ord bash set-vpc-ranges.sh
```

Validate that the VPC is properly setup

 - There is 1 VPC (geo-cluster-gecko)
 - It should have the linodes in them
 - All linodes in the VPC have an assigned IP range on top of their individual assigned IP

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
$ k delete -f geo-cluster-gecko.yaml
```
