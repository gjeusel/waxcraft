import logging
import numpy as np

import sys
from pathlib import Path

from handle_data import SolarMapVisu, SolarMapDatas
from model import LargeNet, ShortNet, SolarMapModel, generate_train_test_sets

from torchvision import transforms

import torch
from torch.autograd import Variable
import torch.nn as nn
import torch.optim as optim

log = logging.basicConfig(format='%(asctime)s %(levelname)s:%(message)s',
                          level=logging.INFO,
                          datefmt='%I:%M:%S')

HOME = Path.home()
sys.path.append((HOME / 'src/deepRoof').as_posix())

# Parameters for pre-processing:
preproc_param = dict(
    transform_train=transforms.Compose(
        [transforms.Resize(size=(64, 64)),
         transforms.ToTensor(),
         transforms.Normalize(mean=(0.5, 0.5, 0.5),
                              std=(0.5, 0.5, 0.5)),
         ]),
    transform_test=transforms.Compose(
        [transforms.Resize(size=(64, 64)),
         transforms.ToTensor(),
         transforms.Normalize(mean=(0.5, 0.5, 0.5),
                              std=(0.5, 0.5, 0.5)),
         ]),
    limit_load=100,
)

qtrainset, qtestset = generate_train_test_sets(
    mode='train-test', **preproc_param)


dataloader = torch.utils.data.DataLoader(
    qtrainset, batch_size=4, shuffle=True, num_workers=4)
it = iter(dataloader)
im, labels = next(it)
im, labels = Variable(im), Variable(labels)


# Hyper Parameters for the CNN model
hyper_param = dict(
    num_epochs=5,
    criterion=nn.CrossEntropyLoss(),
    optimizer_func=optim.Adam,
    optimizer_args={'lr': 0.001},
)
qmodel = SolarMapModel(qtrainset, qtestset)
# qmodel.process(ShortNet, **hyper_param)

net = ShortNet(input_shape=(3, qtrainset.width, qtrainset.height))

basic_layer = nn.Sequential(
    nn.Conv2d(3, 16, kernel_size=2),
    nn.BatchNorm2d(16),
    nn.ReLU(),
    nn.MaxPool2d(2)
)
