#!/usr/bin/env bash
#
#
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca



cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

EXTERNAL_IP=`ip addr show ens18 | grep 'inet ' | awk '{print $2}'`
EXTERNAL_IP=${EXTERNAL_IP%/*}

for id_instance in 0 1 2; do
cat > worker-${id_instance}-csr.json <<EOF
{
  "CN": "system:node:worker-${id_instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

INTERNAL_IP=192.168.8.2${id_instance}
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=worker-${id_instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  worker-${id_instance}-csr.json | cfssljson -bare worker-${id_instance}
done


cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager


cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy


cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

EXTERNAL_IP=`ip addr show ens18 | grep 'inet ' | awk '{print $2}'`
EXTERNAL_IP=${EXTERNAL_IP%/*}
KUBERNETES_PUBLIC_ADDRESS=$EXTERNAL_IP

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,192.168.8.10,192.168.8.11,192.168.8.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes


cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "FR",
      "L": "Rennes",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Bretagne"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

for id_instance in 0 1 2; do
  echo "copying ca.pem worker-${id_instance}-key.pem worker-${id_instance}.pem to worker-${id_instance} "
  scp ca.pem worker-${id_instance}-key.pem worker-${id_instance}.pem root@worker-${id_instance}:~/
done

for instance in controller-0 controller-1 controller-2; do
  echo "copying ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pemi to ${instance}"
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem root@${instance}:~/
done


