#!/bin/bash

# Use the "crictlurl" environmental variable to optionally specify the download URL.

# Install crictl
defaulturl="https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-arm64.tar.gz"
if [ -z ${crictlurl+x} ]; then crictlurl=$defaulturl; fi
wget -O - $crictlurl | \
tar -xz -C /usr/bin/

# Configure crictl
tee /etc/crictl.yaml<<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
pull-image-on-create: false
EOF

while (true); do
    containerid=$(sudo crictl ps| grep storageinitializer-modeldata | awk '{print $1}')
    if [[ -n ${containerid} ]]; then 
        echo "Patching found storagerinitializer container"
        sudo crictl update --cpu-quota 200000 --cpu-period 200000 $containerid
    fi
    sleep 3
done