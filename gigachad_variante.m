clear all
close all
addpath(genpath('Vorlagen/MatlabFns/Projective'));

dina4 = [210,297];

img = imread("images/coins6.jpeg");
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

gray_p = rgb2gray(persp);

[centers,radii] = imfindcircles(gray_p,[25 50],ObjectPolarity="dark", Sensitivity=0.9);
masks = circles2mask(centers, radii, imsize);
persp_masked = persp.*repmat(uint8(masks),[1 1 3]);

res = zeros(length(radii),1);
persp_text = persp;

coins = [0.01, 0.02, 0.1, 0.05, 0.2, 1.0, 0.5, 2.0];
% 2 pixel per milli -> ./2  für radius mal 3 für mm Konversion
radiusse = [16.25, 18.75, 19.75, 21.25, 22.25, 23.25, 24.25, 25.75].*3./2;
lower = radiusse - [2, diff(radiusse)/2];

scale_fac = 1.0;
sorted_radii = sort(radii,'descend');
if sorted_radii(1) > lower(8)
    scale_fac = sorted_radii(1)/radiusse(8);
    radiusse = radiusse.*scale_fac;
end
lower = radiusse - [2, diff(radiusse)/2];
upper = radiusse + [diff(radiusse)/2, 2];


b_avg = 0;
b_std = [];
num_considered = 0;
for i = 1:length(radii)
    f(i).r = radii(i);
    f(i).c = centers(i,:);
    
    % masken erzeugen
    msk_outer = circles2mask(f(i).c,f(i).r, imsize);
    msk_inner = circles2mask(f(i).c, f(i).r*0.7, imsize);
    msk_ring = msk_outer & ~msk_inner;

    outer_ring = persp.*repmat(uint8(msk_ring), [1 1 3]);
    inner_circle = persp.*repmat(uint8(msk_inner), [1 1 3]);

    lab_ring = rgb2lab(outer_ring);
    lab_circle = rgb2lab(inner_circle);

    f(i).b_ring = mean2(lab_ring(:,:,3));
    f(i).b_circle = mean2(lab_circle(:,:,3));

    if abs(f(i).b_circle - f(i).b_ring) < 0.015
        b_avg = b_avg + f(i).b_circle;
        b_std(i) = f(i).b_circle;
        num_considered = num_considered + 1;
    end

end
b_avg = b_avg/num_considered % durchs. b-wert des in kreises
b_std = std(b_std)

b_gw = 0.03;
if num_considered == 1
    b_gw = 0.03;
elseif b_std > 0.01
    b_gw = b_avg;
end

for i = 1:length(radii)
    
    % debug only
    fprintf("b-Ring: %f, b-Kreis innen: %f, Radius Münze: %f\n", f(i).b_ring, f(i).b_circle, f(i).r)
    
    if (f(i).b_circle - f(i).b_ring) > 0.015 && f(i).r > lower(7) % 2 Euro: diff in color & größer als 50 cent lower
        res(i) = 2.0;
    elseif (f(i).b_circle - f(i).b_ring < -0.015) && f(i).r > lower(5) && f(i).r < upper(7) % 1 Euro
        res(i) = 1.0;
    elseif (f(i).b_circle > b_gw) % kein Kupfer (?)
        if (f(i).r > radiusse(6)) % 50 cent
            res(i) = 0.5;
        elseif (f(i).r <= radiusse(6) && f(i).r >= lower(5)) % 20 cent
            res(i) = 0.2;
        else % 10 cent
            res(i) = 0.1;
        end
    else % Kupfer (?)
        if (f(i).r > lower(3)) % 5 cent
            res(i) = 0.05;
        elseif (f(i).r > lower(2) && f(i).r < upper(2)) % 2 cent
            res(i) = 0.02;
        else % 1 cent
            res(i) = 0.01;
        end
    end
    
    persp_text = insertText(persp_text, f(i).c+[f(i).r,0], res(i), FontSize=18,TextBoxColor='y', ...
    BoxOpacity=0.4,TextColor="white");
    %figure
    %imshow(outer_ring)
    
end

figure
imshow(persp_text)

h = viscircles(centers,radii);
