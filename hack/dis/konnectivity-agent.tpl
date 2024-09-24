apiVersion: apps/v1
# Alternatively, you can deploy the agents as Deployments. It is not necessary
# to have an agent on each node.
kind: DaemonSet
metadata:
  labels:
    k8s-app: konnectivity-agent
  namespace: kube-system
  name: konnectivity-agent
spec:
  #replicas: 2
  #strategy:
  #  type: RollingUpdate
  #  rollingUpdate:
  #    maxSurge: 1
  #    maxUnavailable: 50%
  selector:
    matchLabels:
      k8s-app: konnectivity-agent
  template:
    metadata:
      labels:
        k8s-app: konnectivity-agent
    spec:
      priorityClassName: system-cluster-critical
      tolerations:
      # these tolerations are to have the daemonset runnable on control plane nodes
      # remove them if your control plane nodes should not run pods
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
        - image: julsemaan/proxy-agent-amd64:a419d24765f42ac0f4c3ebaad57cb4d66728a81f
          name: konnectivity-agent
          command: ["/proxy-agent"]
          env:
            - name: MY_K8S_HOST
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
          command: ["/bin/bash"]
          args:
            - -c
            - |
              /proxy-agent --logtostderr=true \
                --ca-cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
                --proxy-server-port=8132 \
                --admin-server-port=8133 \
                --health-server-port=8134 \
                --service-account-token-path=/var/run/secrets/tokens/konnectivity-agent-token \
                --proxy-server-host=MY_SERVER_IP \
                --agent-identifiers=host=$MY_K8S_HOST
          volumeMounts:
            - mountPath: /var/run/secrets/tokens
              name: konnectivity-agent-token
          livenessProbe:
            httpGet:
              port: 8134
              path: /healthz
            initialDelaySeconds: 15
            timeoutSeconds: 15
      serviceAccountName: konnectivity-agent
      volumes:
        - name: konnectivity-agent-token
          projected:
            sources:
              - serviceAccountToken:
                  path: konnectivity-agent-token
                  audience: system:konnectivity-server