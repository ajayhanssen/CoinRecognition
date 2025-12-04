clear all
close all
addpath(genpath('Vorlagen/MatlabFns/Projective'));

dina4 = [210,297];

% 2 -> no rectification, 3,8 -> not all coins properly detected
img = imread("images/coins8.jpeg");
gray = rgb2gray(img);

edges = edge(gray, 'canny', [0.02, 0.3]);
edges = imdilate(edges, strel('line', 10, 5));

% detect bounds
boundaries = bwboundaries(edges);

tolerance = 0.02;
largest_area = 0;
l_poly = 0;

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

% throw error if area poly < imsize/4
if largest_area < (size(img,1) * size(img,2)) / 4
    error("Unable to recognize Sheet correctly! Use better illumination or" + ...
        " improve sheet location!")
end
figure
tiledlayout(1,2)
nexttile
imshow(edges)

nexttile
imshow(img);
hold on;
plot(l_poly(:,2), l_poly(:,1), 'r', 'LineWidth', 2)
hold off

%% perspective transform

% with homography
% x1 = [l_poly(1,2), l_poly(2,2), l_poly(3,2), l_poly(4,2)
%       l_poly(1,1), l_poly(2,1), l_poly(3,1), l_poly(4,1)
%       1                 1            1            1];
% x2 = [10 imsize(1) imsize(1)    10
%       10    10      imsize(2) imsize(2)
%       1    1        1          1];

% target size
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


%% detect coins
figure
tiledlayout(1,2)
nexttile
imshow(persp)

gray_p = rgb2gray(persp);

% brightn_diff = reshape([162.4 181.9 203.3], [1 1 3]) - mean(persp, [1 2]);
% persp = persp + uint8(round(brightn_diff*0.5));

[centers,radii] = imfindcircles(gray_p,[25 50],ObjectPolarity="dark", Sensitivity=0.9);
[sorted_radii, sort_idx] = sort(radii, 'descend');
sorted_centers = centers(sort_idx, :);

res = zeros(length(radii),1);
persp_text = persp;

coins = [0.01, 0.02, 0.1, 0.05, 0.2, 1.0, 0.5, 2.0];
% 2 pixel per milli -> ./2  für radius mal 3 für mm Konversion
radiusse = [16.25, 18.75, 19.75, 21.25, 22.25, 23.25, 24.25, 25.75].*3./2;
lower = radiusse - [2, diff(radiusse)/2];

scale_fac = 1.0;
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

    % lightness, chromaticity red-green, chromaticity blue-yellow
    lab_ring = rgb2lab(outer_ring);
    lab_circle = rgb2lab(inner_circle);

    f(i).b_ring = mean2(lab_ring(:,:,3));
    f(i).b_circle = mean2(lab_circle(:,:,3));
    f(i).a_ring = mean2(lab_ring(:,:,2));
    f(i).a_circle = mean2(lab_circle(:,:,2));

    if abs(f(i).b_circle - f(i).b_ring) < 0.015
        b_avg = b_avg + f(i).b_circle;
        b_std(i) = f(i).b_circle;
        num_considered = num_considered + 1;
    end

end
b_avg = b_avg/num_considered % durchs. b-wert der inneren kreise
b_std = std(b_std)

b_gw = 0.03;
if num_considered == 1
    b_gw = 0.03;
elseif b_std > 0.01
    b_gw = b_avg;
end

for i = 1:length(radii)

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

    fprintf("a-Ring: %f, a-Kreis: %f, b-Ring: %f, b-Kreis: %f, Radius: %f, c: %f\n", ...
        f(i).a_ring, f(i).a_circle, f(i).b_ring, f(i).b_circle, f(i).r, res(i))

    persp_text = insertText(persp_text, f(i).c+[f(i).r,0], res(i), FontSize=18,TextBoxColor='y', ...
    BoxOpacity=0.4,TextColor="white");
    %figure
    %imshow(outer_ring)
    
end

nexttile
imshow(persp_text)

h = viscircles(centers,radii);
