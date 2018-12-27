#!/usr/bin/env python3
from imgaug import augmenters as iaa
import numpy as np
import cv2
import os
import scipy.misc
import sys



class ImageAug(object):
    
    
    def __init__(self):
        seq = iaa.Sequential(
            [
                iaa.AdditiveGaussianNoise(scale=(0, 0.04*255)),
                iaa.GaussianBlur((0, 0.75)), # blur images with a sigma between 0 and 3.0
                iaa.Sharpen(alpha=(0, 0.5), lightness=(0.75, 1.5)), # sharpen images
                iaa.Dropout((0.01, 0.05)), # randomly remove up to 10% of the pixels
                iaa.Affine(rotate=(-1, 1)),
                iaa.Affine(scale=(0.9, 1)),
                iaa.Affine(shear=(-30, 30))
            ],
            random_order=True
        )
        self.seq = seq


    def __call__(self, img):
        images_aug = self.seq.augment_image(img)
        return images_aug

if __name__ == '__main__':
    for filename in os.listdir("/home/babek/kaldi-hwr/egs/augend2end/v1/data/preaug"):
        image = cv2.imread("/home/babek/kaldi-hwr/egs/augend2end/v1/data/preaug/"+filename)
        aug = ImageAug()
        scipy.misc.imsave("/home/babek/kaldi-hwr/egs/augend2end/v1/data/pre_grayscale/"+filename.replace("k", "a"), aug(image))


