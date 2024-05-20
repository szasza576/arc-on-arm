#!/bin/sh

echo "Downloading kubectl..."
wget -qO /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(wget -qO - https://storage.googleapis.com/kubernetes-release/release/stable.txt 2> /dev/null)/bin/linux/arm64/kubectl 2> /dev/null
chmod +x /usr/bin/kubectl
echo "Download finished"

# Start watching
echo "Waiting for a new realyserver deployment to be patched"
sleeptime=30 # It checks in every 30 sec until it finds a resource. Then it changes to 120 secs.
while (true); do
    test=$(kubectl get deployments -A -l app=relayserver,ml.azure.com/amlarc-system=true --no-headers 2>/dev/null | grep relayserver)
    if [[ -n "${test}" ]]; then 
        namespace=$(kubectl get deployments -A -l app=relayserver,ml.azure.com/amlarc-system=true --no-headers 2>/dev/null | grep relayserver | head -n 1 | awk '{print $1}')
        image=$(kubectl get deployments -n $namespace relayserver -o jsonpath='{.spec.template.spec.containers[0].image}')
        if echo "$image" | grep -q "localhost"; then
            echo "Found a resource in namespace: $namespace but it is already patched."
        else
           echo "Patching relayserver deployment"
           kubectl patch deployments -n $namespace relayserver --patch='{"spec":{"template":{"spec":{"containers":[{"name":"relayserver","image":"'${image/mcr.microsoft.com/localhost:5000}'"
}]}}}}'
        fi
        sleeptime=120
    else
        sleeptime=30
    fi
    sleep $sleeptime
done


kubectl get deployments -A -l app=relayserver