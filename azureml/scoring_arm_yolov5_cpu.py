import os
import sys
import base64
import json
import time
import cv2
import numpy as np

from azureml.contrib.services.aml_request import rawhttp
from azureml.contrib.services.aml_response import AMLResponse
import onnxruntime

def image_preprocess(request_data):
    request_json = json.loads(request_data)
    image_base64 = request_json["input_data"]["data"][0]
    
    # Decode the base64 string to bytes
    image = base64.b64decode(image_base64)

    np_img = np.frombuffer(image, np.uint8)
    ori_img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
    if ori_img is None:
        raise ValueError("Invalid image format")

    img_height, img_width = ori_img.shape[:2]
    img = cv2.cvtColor(ori_img, cv2.COLOR_BGR2RGB)
    img = cv2.resize(img, img_size)
#    img = np.array(img) / 255.0
    img = np.transpose(img, (2, 0, 1))  # Channel first --> CHV
    img = np.expand_dims(img, axis=0).astype(np.float32)

    return img_height, img_width, img

def postprocess(outputs, labels, confidence_thres=0.3, iou_thres=0.1):
    # Align the dimensions
    outputs = np.transpose(np.squeeze(outputs))
    outputs = np.transpose(outputs, [1,0])

    # Filter out high confidence findings based on box confidence
    mask = outputs[:, 4] >= confidence_thres
    outputs = outputs[mask]

    # Get the number of rows in the outputs array
    rows = outputs.shape[0]

    # Lists to store the bounding boxes, scores, and class IDs of the detections
    boxes = []
    scores = []
    class_ids = []

    # Iterate over each row in the outputs array
    for i in range(rows):
        # Extract the class scores from the current row
        classes_scores = outputs[i][5:]

        # Find the maximum score among the class scores
        max_score = np.amax(classes_scores)

        # If the maximum score is above the confidence threshold
        if (max_score >= confidence_thres) :
            # Get the class ID with the highest score
            class_id = np.argmax(classes_scores)

            # Extract the bounding box coordinates from the current row
            x, y, w, h = outputs[i][0], outputs[i][1], outputs[i][2], outputs[i][3]

            # Calculate the scaled coordinates of the bounding box
            x1 = (x - w / 2) / img_size[0]
            y1 = (y - h / 2) / img_size[1]
            x2 = x1 + w / img_size[0]
            y2 = y1 + h / img_size[1]

            # Add the class ID, score, and box coordinates to the respective lists
            if (x1 > 0) and (y1 > 0) and (x2 < 1) and (y2 < 1) :
                class_ids.append(class_id)
                scores.append(outputs[i][4])
                boxes.append([x1, y1, x2, y2])

    # Apply non-maximum suppression to filter out overlapping bounding boxes
    indices = cv2.dnn.NMSBoxes(boxes, scores, confidence_thres, iou_thres)

    # Iterate over the selected indices after non-maximum suppression
    detections = []
    for i in indices:
        detections.append({
            "box": {
                "topX": float(boxes[i][0]),
                "topY": float(boxes[i][1]),
                "bottomX": float(boxes[i][2]),
                "bottomY": float(boxes[i][3])
            },
            "label": labels[class_ids[i]],
            "score": float(scores[i])
        })
    response_raw = [{'boxes': detections}]
    response_json = json.dumps(response_raw)
    return response_json

def inference(request_data):
    print("Running inference.")
    full_process = time.time()
    img_height, img_width, img = image_preprocess(request_data)
    inference_start = time.time()
    results=model.run([], {'input':img})[0]
    print(f"inference time: {(time.time() - inference_start) * 1000} ms")
    inference_result=postprocess(results, classes, confidence_thres=box_score_thresh, iou_thres=nms_iou_thresh)
    print(f"processing time: {(time.time() - full_process) * 1000} ms")
    return inference_result

def init():
    global model
    global img_size
    global nms_iou_thresh
    global box_score_thresh
    global classes

    print("Running the initializations")

    # Set model and settings file path
    model_path = os.path.join(os.getenv('AZUREML_MODEL_DIR'), 'model/model.onnx')
    settings_path = os.path.join(os.getenv('AZUREML_MODEL_DIR'), 'model/settings.json')
    labels_path = os.path.join(os.getenv('AZUREML_MODEL_DIR'), 'model/labels.json')

    # Read the settings file
    try:
        with open(settings_path) as file:
            model_settings = json.load(file)
    except FileNotFoundError:
        print(f"Error: The file at {settings_path} was not found.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: The file at {settings_path} is not a valid JSON.")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)

    # Read the labels file
    with open(labels_path) as file:
        classes = json.load(file)
    try:
        with open(labels_path) as file:
            classes = json.load(file)
    except FileNotFoundError:
        print(f"Error: The file at {labels_path} was not found.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: The file at {labels_path} is not a valid JSON.")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)

    # Extract model configuration parameters
    img_size=(model_settings['img_size'],model_settings['img_size'])
    nms_iou_thresh=model_settings['nms_iou_thresh']
    box_score_thresh=model_settings['box_score_thresh']

    # Load the model
    model = onnxruntime.InferenceSession(model_path)

    print("Model loaded")

@rawhttp
def run(request):
    if request.method == "GET":
        response_body = str.encode(request.full_path)
        return AMLResponse(response_body, 200)

    elif request.method == "POST":
        request_body = request.get_data()
        result = str.encode(inference(request_body))
        return AMLResponse(result, 200)
    else:
        return AMLResponse("bad request", 500)
