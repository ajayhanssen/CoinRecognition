clear all
close all
addpath(genpath('Vorlagen/MatlabFns/Projective'));

dina4 = [210,297];

img = imread("images/coins3.jpeg");
gray = rgb2gray(img);
imsize = size(gray);

%imshow(gray)

edges = edge(gray, 'canny', [0.05, 0.3]);
edges = imdilate(edges, strel('line', 3, 0.5));


boundaries = bwboundaries(edges);

tolerance = 0.02;
largest_area = 0;
l_poly = 0;

imshow(img);
hold on;
for k = 1:length(boundaries)
    boundary = boundaries{k};
    p_reduced = reducepoly(boundary,tolerance);

    if size(p_reduced,1) ~= 5
        continue
    end
    
    area = polyarea(p_reduced(:,2), p_reduced(:,1));
    if area > largest_area
        l_poly = p_reduced;
        largest_area = area;
    end

    %plot(p_reduced(:,2), p_reduced(:,1), 'b', 'LineWidth', 2);
end

plot(l_poly(:,2), l_poly(:,1), 'r', 'LineWidth', 2)
hold off

%% perspective transform

x1 = [l_poly(1,2), l_poly(2,2), l_poly(3,2), l_poly(4,2)
      l_poly(1,1), l_poly(2,1), l_poly(3,1), l_poly(4,1)
      1                 1            1            1];
x2 = [10 imsize(1) imsize(1)    10
      10    10      imsize(2) imsize(2)
      1    1        1          1];

imshow(gray)
Hsc = homography2d(x1, x2);
persp = imTrans(img, Hsc);
imshow(persp)

%% detect coins
