#!/bin/sh

echo "Downloading kubectl..."
wget -qO /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(wget -qO - https://storage.googleapis.com/kubernetes-release/release/stable.txt 2> /dev/null)/bin/linux/arm64/kubectl 2> /dev/null
chmod +x /usr/bin/kubectl
echo "Download finished"

echo "Download Prometheus patch config file"
wget -q https://raw.githubusercontent.com/szasza576/arc-on-arm/main/azureml/aml-patcher/prometheus-patch.yaml 2> /dev/null
echo "Download finished"

echo ""
echo "IMPORTANT"
echo "Note that this hack works with the current Prometheus version used by Azure Arc."
echo "Nevertheless, I reported that this is heavily outdated."
echo "The new Prometheus version will have different config and this script may fail with that."
echo ""

# Start watching
echo "Waiting for a new Prometheus CRD to be patched"
sleeptime=30 # It checks in every 30 sec until it finds a resource. Then it changes to 120 secs.
while (true); do
    test=$(kubectl get Prometheus -A -l app=azureml-prometheus --no-headers 2>/dev/null | grep prom-prometheus)
    if [[ -n "${test}" ]]; then 
        namespace=$(kubectl get Prometheus -A -l app=azureml-prometheus --no-headers 2>/dev/null | head -n 1 | grep prom-prometheus | awk '{print $1}')
        if kubectl get Prometheus -n $namespace prom-prometheus -o jsonpath='{.spec.baseImage}' | grep -q "quay.io"; then
            echo "Found a resource in namespace: $namespace but it is already patched."
        else
           echo "Patching Prometheus resource"
           kubectl patch Prometheus -n $namespace prom-prometheus --type json --patch-file /prometheus-patch.yaml
        fi
        sleeptime=120
    else
        sleeptime=30
    fi
    sleep $sleeptime
done