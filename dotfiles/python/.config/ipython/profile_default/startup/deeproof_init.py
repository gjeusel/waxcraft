import logging
import sys
import time
from pathlib import Path

import numpy as np

import torch
import torch.nn as nn
import torch.optim as optim
# Custom imports
from deeproof.common import (DATA_DIR, IMAGE_DIR, SNAPSHOT_DIR, SUBMISSION_DIR,
                             setup_logs)
from deeproof.dataset import RoofDataset, train_valid_split
from deeproof.model_handler import DeepRoofHandler
from deeproof.neuro.handcraft import ResNet, ShortNet
from deeproof.prediction import predict, write_submission_file
from deeproof.train import train
from deeproof.validation import validate
from torch.autograd import Variable
from torchvision import transforms

log = logging.basicConfig(
    format='%(asctime)s %(levelname)s:%(message)s',
    level=logging.INFO,
    datefmt='%I:%M:%S')

HOME = Path.home()

# Setup logs
run_name = time.strftime("%Y-%m-%d_%H%M-") + "resnet50-L2reg-new-data"
logger = setup_logs(SNAPSHOT_DIR, run_name)

# Normalization on ImageNet mean/std for finetuning
normalize = transforms.Normalize(
    mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])

# Augmentation + Normalization for full training
ds_transform_augmented = transforms.Compose([
    transforms.RandomResizedCrop(64),
    # PowerPIL(),
    transforms.ToTensor(),
    # ColorJitter(), # Use PowerPIL instead, with PillowSIMD it's much more efficient
    normalize,
    # Affine(
    #    rotation_range = 15,
    #    translation_range = (0.2,0.2),
    #    shear_range = math.pi/6,
    #    zoom_range=(0.7,1.4)
    # )
])

# Normalization only for validation and test
ds_transform_raw = transforms.Compose(
    [transforms.Resize((64, 64)),
     transforms.ToTensor(), normalize])

drq = DeepRoofHandler(
    logger,
    ds_transform_augmented,
    ds_transform_raw,
    sampler=None,
    limit_load=100)

im, labels, labels_bin = drq.X_train[0]
y_true = labels
y_pred = torch.Tensor([[0.2, 0.1, 0.6, 0.1]] * 4)

# model = ResNet(50)
net = ShortNet((3, 64, 64))

# criterion = ConvolutedLoss()
weight = torch.Tensor([1., 1.971741, 3.972452, 1.824547])
criterion = torch.nn.MultiLabelSoftMarginLoss(weight=weight)
criterion = torch.nn.CrossEntropyLoss(weight=weight)

# Note, p_training has lr_decay automated
optimizer = optim.SGD(
    net.parameters(), lr=1e-2, momentum=0.9,
    weight_decay=0.0005)  # Finetuning whole model

# drq.train(epochs=1, model=net, loss_func=criterion, optimizer=optimizer, record_model=False)
