# AzureML extension

## Rebuild relayserver
The relayserver component uses a C# code and hence that container shall be rebuilt with ARM64 specific .NET framework.

Build ARM64 container for relayserver and push to the local repository (run it on the ARM board):
```bash
docker build -t localhost:5000/azureml/amlarc/docker/relayserver:1.1.88 https://github.com/szasza576/arc-on-arm.git#main:azureml/relayserver
docker push localhost:5000/azureml/amlarc/docker/relayserver:1.1.88
```

## Extension patchers
There is a set of patcher scripts which helps you to easily change the images to ARM64 images. This runs in the background and do the patching when needed.

Deploy the patcher tools:
```powershell
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-on-arm/main/azureml/aml-patcher/aml-patcher.yaml
```

## Deploy Azure ML extension
Now you can deploy the Azure ML extension as written in the documentation.

You can use the portal and add the extension (deploy only the Prometheus and the Volcano components) or you can use the following Azure CLI command:
```powershell
$ResourceGroup="arc-on-arm"
$Location="westeurope"
$ClusterName="rock5b"
$AMLExtName="azureml"

az k8s-extension create `
  --name $AMLExtName `
  --cluster-name $ClusterName `
  --resource-group $ResourceGroup `
  --extension-type Microsoft.AzureML.Kubernetes `
  --config enableTraining=True `
           enableInference=True `
           inferenceRouterServiceType=LoadBalancer `
           allowInsecureConnections=True `
           inferenceLoadBalancerHA=False `
  --cluster-type connectedClusters  `
  --scope cluster
```

## Attach the cluster to the AzureML workspace
This steps requires an already deployed AzureML workspace. You shall deploy it before proceeding here.

The following commands will attach the Arc enabled Kubernetes cluster to the AzureML workspace as a Kubernetes cluster. You can achieve it on the portal as well and with the below commands as well.

Create an idetity for the cluster:
```powershell
$ArcMLExtIdentityName="rock5b-identity"

az identity create `
  --name $ArcMLExtIdentityName `
  --resource-group $ResourceGroup

$AMLExtIdentityID=$(az identity show `
    --name  $ArcMLExtIdentityName `
    --resource-group $ResourceGroup `
    --query id `
    --output tsv)
```
Do the attachment:
```powershell
$MLWorkspaceName="armtesting"

# Install the "ml" Azure CLI extension if not done yet. Shall run only once.
az extension add --upgrade --yes --name ml

$ArcK8sID=$(az connectedk8s show `
    --name $ClusterName `
    --resource-group $ResourceGroup `
    --query id `
    --output tsv)

az ml compute attach `
  --resource-group $ResourceGroup `
  --workspace-name $MLWorkspaceName `
  --type Kubernetes `
  --name $ClusterName-compute `
  --resource-id $ArcK8sID `
  --identity-type UserAssigned `
  --user-assigned-identities $AMLExtIdentityID
```

# Troubleshoot
## I get ImgPullError
This repo is not continuously updated and if Azure updates the versions then it will fall out of sync. Please update the version numbers in the relevant files or open an issue here so I'm notified.
## Model inference timeout
You can deploy AI models with the default Azure ML environment but those are based on x86-64 codes and hence those will run within a QEMU emulated environment. It means it will be extremely slow.

You need to create an ARM64 environment image in AzureML and upload it to the AzureML's registry. It is important to build the whole image what AzureML can import. If you also specify a conda file then AzureML tries to build the image and of course it cannot deal with ARM64 images so it will fail. I will create a guide about this.

Just as a reference: running a Yolov5 on a weak notebook with (Nvidia 940m](https://www.techpowerup.com/gpu-specs/geforce-940m.c2643) takes 150 ms to score an image. The same model can be deployed here but will run on CPU due to lacking Nvidia card* and also it runs inside QEMU and it takes 100 seconds (yes sec, not ms) to score.

*As the Rock5B has an PCIe 3.0 x4 M.2. connector hence it is possible to attach an Nvidia card to it ... but we will use its internal AI accelerator in the next round.
