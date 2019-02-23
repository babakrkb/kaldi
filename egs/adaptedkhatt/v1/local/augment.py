#!/usr/bin/env python3
from imgaug import augmenters as iaa
import numpy as np
import cv2
import os
import scipy.misc
import sys



class ImageAug(object):
    
    
    def __init__(self):
        seq1 = iaa.Sequential(
            [
                iaa.AdditiveGaussianNoise(scale=(0, 0.04*255)),
                iaa.GaussianBlur((0, 0.75)), # blur images with a sigma between 0 and 3.0
                iaa.Sharpen(alpha=(0, 0.5), lightness=(0.75, 1.5)), # sharpen images
                iaa.Dropout((0.01, 0.05)), # randomly remove up to 10% of the pixels
                iaa.Affine(rotate=(-1, 1)),
                iaa.Affine(scale=(0.9, 1)),
                iaa.Affine(shear=(-30, -30))
            ],
            random_order=True
        )
        seq2 = iaa.Sequential(
            [
                iaa.AdditiveGaussianNoise(scale=(0, 0.04*255)),
                iaa.GaussianBlur((0, 0.75)), # blur images with a sigma between 0 and 3.0
                iaa.Sharpen(alpha=(0, 0.5), lightness=(0.75, 1.5)), # sharpen images
                iaa.Dropout((0.01, 0.05)), # randomly remove up to 10% of the pixels
                iaa.Affine(rotate=(-1, 1)),
                iaa.Affine(scale=(0.9, 1)),
                iaa.Affine(shear=(-15, -15))
            ],
            random_order=True
        )
        seq3 = iaa.Sequential(
            [
                iaa.AdditiveGaussianNoise(scale=(0, 0.04*255)),
                iaa.GaussianBlur((0, 0.75)), # blur images with a sigma between 0 and 3.0
                iaa.Sharpen(alpha=(0, 0.5), lightness=(0.75, 1.5)), # sharpen images
                iaa.Dropout((0.01, 0.05)), # randomly remove up to 10% of the pixels
                iaa.Affine(rotate=(-1, 1)),
                iaa.Affine(scale=(0.9, 1)),
                iaa.Affine(shear=(30, 30))
            ],
            random_order=True
        )
        seq4 = iaa.Sequential(
            [
                iaa.AdditiveGaussianNoise(scale=(0, 0.04*255)),
                iaa.GaussianBlur((0, 0.75)), # blur images with a sigma between 0 and 3.0
                iaa.Sharpen(alpha=(0, 0.5), lightness=(0.75, 1.5)), # sharpen images
                iaa.Dropout((0.01, 0.05)), # randomly remove up to 10% of the pixels
                iaa.Affine(rotate=(-1, 1)),
                iaa.Affine(scale=(0.9, 1)),
                iaa.Affine(shear=(15, 15))
            ],
            random_order=True
        )
        self.seq1 = seq1
        self.seq2 = seq2
        self.seq3 = seq3
        self.seq4 = seq4


    def __call__(self, img):
        images_aug1 = self.seq1.augment_image(img)
        images_aug2 = self.seq2.augment_image(img)
        images_aug3 = self.seq3.augment_image(img)
        images_aug4 = self.seq4.augment_image(img)
        return [images_aug1,images_aug2,images_aug3,images_aug4]

if __name__ == '__main__':
    # for filename in os.listdir("/home/babek/kaldi-hwr/egs/augend2end/v1/data/preaug"):
    #     image = cv2.imread("/home/babek/kaldi-hwr/egs/augend2end/v1/data/preaug/"+filename)
    #     aug = ImageAug()
    #     scipy.misc.imsave("/home/babek/kaldi-hwr/egs/augend2end/v1/data/pre_grayscale/"+filename.replace("k", "a"), aug(image))
    for filename in os.listdir("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/normalized"):
        if filename.startswith("A00") and filename.replace("A", "B") not in os.listdir("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/preaug") :
            image = cv2.imread("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/normalized/"+filename)
            aug = ImageAug()
            scipy.misc.imsave("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/preaug/"+filename.replace("A", "B"), aug(image)[0])
            scipy.misc.imsave("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/preaug/"+filename.replace("A", "C"), aug(image)[1])
            scipy.misc.imsave("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/preaug/"+filename.replace("A", "D"), aug(image)[2])
            scipy.misc.imsave("/home/babek/kaldi-hwr/egs/adaptedkhatt/v1/data/preaug/"+filename.replace("A", "E"), aug(image)[3])
