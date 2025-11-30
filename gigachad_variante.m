clear all
close all
addpath(genpath('Vorlagen/MatlabFns/Projective'));

dina4 = [210,297];

img = imread("images/coins4.jpeg");
gray = rgb2gray(img);

edges = edge(gray, 'canny', [0.02, 0.3]);
edges = imdilate(edges, strel('line', 10, 5));

figure
imshow(edges)

boundaries = bwboundaries(edges);

tolerance = 0.02;
largest_area = 0;
l_poly = 0;

figure
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

if largest_area < (size(img,1) * size(img,2)) / 4
    error("Unable to recognize Sheet correctly! Use better illumination or" + ...
        "improve sheet location!")
end

plot(l_poly(:,2), l_poly(:,1), 'r', 'LineWidth', 2)
hold off

%% perspective transform

% no nono
% x1 = [l_poly(1,2), l_poly(2,2), l_poly(3,2), l_poly(4,2)
%       l_poly(1,1), l_poly(2,1), l_poly(3,1), l_poly(4,1)
%       1                 1            1            1];
% x2 = [10 imsize(1) imsize(1)    10
%       10    10      imsize(2) imsize(2)
%       1    1        1          1];
imsize = dina4*3;
len1 = norm(l_poly(1,:)-l_poly(2,:));
len2 = norm(l_poly(2,:)-l_poly(3,:));
if len1 < len2
    imsize = flip(imsize);
end


src = [l_poly(1:4,2), l_poly(1:4,1)];
dst = [10,10;
       imsize(2), 10;
       imsize(2), imsize(1);
       10, imsize(1)];

tform = fitgeotrans(src, dst, "projective");

outputView = imref2d([imsize(1), imsize(2)], ...
                     [10, imsize(2)], ...
                     [10, imsize(1)]);

persp = imwarp(img, tform, "OutputView", outputView);
%persp_resized = imresize(persp, dina4, 'Method','lanczos3');

figure
imshow(persp)


%% detect coins
%load("nnet_google.mat")
load("squeezenet.mat")

coins = [0.01, 0.02, 0.1, 0.05, 0.2, 1.0, 0.5, 2.0];
% 2 pixel per milli -> ./2  für radius mal 3 für mm Konversion
radiusse = [16.25, 18.75, 19.75, 21.25, 22.25, 23.25, 24.25, 25.75].*3./2;

radiusse
lower = radiusse - [2, diff(radiusse)/2];
upper = radiusse + [diff(radiusse)/2, 2];

gray_p = rgb2gray(persp);

[centers, radii] = imfindcircles(gray_p,[30 50], ...
    ObjectPolarity="dark", ...
    Sensitivity=0.9);

radii = radii - 0.2;

figure; imshow(persp);
viscircles(centers,radii);

[h, w, ~] = size(persp);

for i = 1:length(radii)

    cx = round(centers(i,1));
    cy = round(centers(i,2));
    padding = round(radii(i) + 10);

    x1 = max(cx - padding, 1);
    x2 = min(cx + padding, w);
    y1 = max(cy - padding, 1);
    y2 = min(cy + padding, h);

    region = persp(y1:y2, x1:x2, :);
    region = im2single(imresize(region, [224 224]));
    %imshow(region)
    scores = predict(net, region)
    label = scores2label(scores, classNames);

    fprintf("Münze %d: %s\n", i, label);

end
