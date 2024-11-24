from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.ai.ml.constants import AssetTypes
from azure.identity import DefaultAzureCredential

import mlflow
from mlflow.tracking.client import MlflowClient

import os
import shutil
import argparse

def convert_model(onnx_model_path):
    from rknn.api import RKNN
    import onnx
    print("Converting ONNX model to RKNN")
    rknn_model_path = onnx_model_path.rsplit('.', 1)[0] + '.rknn'
    # Set quantization to false. Consider to enable it as a later feature.
    do_quant = False

    # Create RKNN object
    rknn = RKNN(verbose=False)

    # Pre-configure model
    print('--> Config model')
    ## Get the input shape from the model
    onnx_model = onnx.load(onnx_model_path)
    input_shapes = [[d.dim_value for d in _input.type.tensor_type.shape.dim] for _input in onnx_model.graph.input]
    if input_shapes[0][0] == 0:
        input_shapes[0][0] = 1
    #rknn.config(dynamic_input=[input_shapes], target_platform=args.rknn_platform)
    rknn.config(target_platform=args.rknn_platform)
    print('done')

    # Load model
    print('--> Loading model')
    ret = rknn.load_onnx(model=onnx_model_path , inputs=['input'], input_size_list=input_shapes)
    if ret != 0:
        print('Load model failed!')
        exit(ret)
    print('done')

    # Build model
    print('--> Building model')
    ret = rknn.build(do_quantization=do_quant)
    if ret != 0:
        print('Build model failed!')
        exit(ret)
    print('done')

    # Export rknn model
    print('--> Export rknn model')
    ret = rknn.export_rknn(rknn_model_path)
    if ret != 0:
        print('Export rknn model failed!')
        exit(ret)
    print('done')

    # Release
    rknn.release()

    return rknn_model_path

parser = argparse.ArgumentParser()
parser.add_argument('--workspace_name', type=str, help='Name of the ML workspace')
parser.add_argument('--resource_group', type=str, help='Name of the ML workspace\'s Resource Group')
parser.add_argument('--subscription_id', type=str, help='Subscription ID of the ML workspace')
parser.add_argument('--job', type=str, help='Name of the training job')
parser.add_argument('--local_dir', type=str, default='./model', help='Name of the temporary local directory')
parser.add_argument('--model_name', type=str, help='Name of the model how it will be registered')
parser.add_argument('--rknn', action='store_true', help='Enable rknn conversion and save the model in RKNN format instead of ONNX')
parser.add_argument('--quant', action='store_true', help='Enable quantization during RKNN conversion') # TODO
parser.add_argument('--rknn_platform', type=str, default='rk3588', help='Define the Rockchip CPU model like RK3588. [i8, fp] for [rk3562,rk3566,rk3568,rk3588] and [u8, fp] for [rk1808,rv1109,rv1126]')
args = parser.parse_args()

# Connect to ML workspace
ml_client = MLClient(DefaultAzureCredential(), args.subscription_id, args.resource_group, args.workspace_name)

# Configure tracking URI
MLFLOW_TRACKING_URI = ml_client.workspaces.get(name=ml_client.workspace_name).mlflow_tracking_uri
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
mlflow_client = MlflowClient()

# Get the best run from an experiment job
mlflow_parent_run = mlflow_client.get_run(args.job.lower())
best_child_run_id = mlflow_parent_run.data.tags['automl_best_child_run_id']
best_run = mlflow_client.get_run(best_child_run_id)

# Create local folders for download
if not os.path.exists(args.local_dir+'-temp'):
    os.mkdir(args.local_dir+'-temp')
if not os.path.exists(args.local_dir):
    os.mkdir(args.local_dir)

# Download labels file
labels_file = mlflow_client.download_artifacts(
    best_run.info.run_id, 'train_artifacts/labels.json', args.local_dir+'-temp'
)
shutil.move(labels_file, args.local_dir)

# Donwload the training dataset references
training_file = mlflow_client.download_artifacts(
    best_run.info.run_id, "train_artifacts/train_df.csv", args.local_dir+'-temp'
)
# Donwload the validation dataset references
validation_file = mlflow_client.download_artifacts(
    best_run.info.run_id, "train_artifacts/val_df.csv", args.local_dir+'-temp'
)

# Download the model
onnx_model_path = mlflow_client.download_artifacts(
    best_run.info.run_id, 'train_artifacts/model.onnx', args.local_dir+'-temp'
)
if args.rknn :
    if args.quant :
        # Donwload the training dataset references
        training_file = mlflow_client.download_artifacts(
            best_run.info.run_id, "train_artifacts/train_df.csv", args.local_dir+'-temp'
        )
        # Donwload the validation dataset references
        validation_file = mlflow_client.download_artifacts(
            best_run.info.run_id, "train_artifacts/val_df.csv", args.local_dir+'-temp'
        )
    rknn_model_path = convert_model(onnx_model_path)
    shutil.move(rknn_model_path, args.local_dir)
else:
    shutil.move(onnx_model_path, args.local_dir)

## Donwload the Conda file
#conda_file = mlflow_client.download_artifacts(
#    best_run.info.run_id, "outputs/conda_env_v_1_0_0.yml", args.local_dir+'-temp'
#)
#shutil.move(conda_file, args.local_dir)

# Donwload the Settings file
settings_file = mlflow_client.download_artifacts(
    best_run.info.run_id, "outputs/mlflow-model/artifacts/settings.json", args.local_dir+'-temp'
)
shutil.move(settings_file, args.local_dir)

# Cleanup temporary folder
shutil.rmtree(args.local_dir+'-temp')

# Register the model
file_model = Model(
    path=args.local_dir,
    type=AssetTypes.CUSTOM_MODEL,
    name=args.model_name,
)
ml_client.models.create_or_update(file_model)

print(f"Model registered: {file_model.name} with ID: {file_model.id}")

# Cleanup local folder
shutil.rmtree(args.local_dir)