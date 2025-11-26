clear all
close all
dina4 = [210,297];

% source functions from lecturer
addpath(genpath('Vorlagen/MatlabFns/Projective'));

img = imread("images/coins1.jpg");
BW = rgb2gray(img);

% origin points
x1 = [2000 3696 2216 128;
      1328 2080 4824 3304;
        1   1   1   1;];

% target points
x2 = [ 20 3840 3840  20;
       20 20   5120  5120;
        1   1   1   1;];
% create H-matrix
Hsc = homography2d(x1, x2);

% perspective transformed image
persp = imTrans(BW,Hsc);

BW = imgaussfilt(BW, 8);
BW = edge(BW, "sobel");

%BW = imdilate(BW);

figure(1)
imshow(BW)



% figure(2)
% tiledlayout(1,2)
% nexttile
% imshow(img)
% nexttile
% imshow(persp)