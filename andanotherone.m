clear all
close all
addpath(genpath('Vorlagen/MatlabFns/Projective'));

dina4 = [210,297];

img = imread("images/coins4.jpeg");
gray = rgb2gray(img);
imsize = size(gray);

%imshow(gray)

edges = edge(gray, 'canny', [0.05, 0.3]);
imshow(edges)
%%

[H, theta, rho] = hough(edges);
peaks = houghpeaks(H, 20, 'Threshold', 0.1*max(H(:)));
lines = houghlines(edges, theta, rho, peaks, 'FillGap', 40, 'MinLength', 40)'

lengths = zeros(length(lines), 5);
figure
imshow(img)
hold on
for i =1:length(lines)
    lengths(i,1) = lines(i).point1(1);
    lengths(i,2) = lines(i).point1(2);
    lengths(i,3) = lines(i).point2(1);
    lengths(i,4) = lines(i).point2(2);
    lengths(i,5) = norm(lines(i).point1-lines(i).point2);
    plot([lengths(i,1), lengths(i,3)], [lengths(i,2), lengths(i,4)], 'LineWidth', 2);
end

lengths = sortrows(lengths, 5);

top4 = lengths(end-3:end,:);



figure; imshow(img); hold on;

for k = 1:length(top4)-1
    plot([top4(k,1), top4(k,3)], [top4(k,2), top4(k,4)], 'LineWidth', 2);
end

% schnittpunkte der linien

L1 = top4(1,:);
L2 = top4(2,:);
L3 = top4(3,:);
L4 = top4(4,:);

P1 = intersectLines(L1(1:2), L1(3:4), L3(1:2), L3(3:4));
P2 = intersectLines(L1(1:2), L1(3:4), L4(1:2), L4(3:4));

P3 = intersectLines(L2(1:2), L2(3:4), L3(1:2), L3(3:4));
P4 = intersectLines(L2(1:2), L2(3:4), L4(1:2), L4(3:4));

points = [P1; P2; P3; P4];
points = order_points(points)

hold on
plot(points(1,1), points(1,2), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
plot(points(2,1), points(2,2), 'bo', 'MarkerSize', 8, 'LineWidth', 2);
plot(points(3,1), points(3,2), 'go', 'MarkerSize', 8, 'LineWidth', 2);
plot(points(4,1), points(4,2), 'yo', 'MarkerSize', 8, 'LineWidth', 2);
hold off


%% perspective transform

x1 = [points(1,1), points(2,1), points(3,1), points(4,1)
      points(1,2), points(2,2), points(3,2), points(4,2)
      1                 1            1            1];
x2 = [10 imsize(1) imsize(1)    10
      10    10      imsize(2) imsize(2)
      1    1        1          1];

imshow(gray)
Hsc = homography2d(x1, x2);
persp = imTrans(img, Hsc);
imshow(persp)


%% funcs
function P = intersectLines(p1, p2, p3, p4)
    % p1 &p2 auf Linie A
    % p3 & p4 auf Linie B

    A = [p2 - p1; p3 - p4]';
    b = (p3 - p1)';
    t = A \ b;
    P = p1 + t(1)*(p2 - p1);
end

function rect = order_points(pts)

    rect = zeros(4,2);

    % Sort by y-pos
    [~, idx] = sort(pts(:,2));
    top = pts(idx(1:2), :);
    bottom = pts(idx(3:4), :);

    % sort t-left and t-right by x
    if top(1,1) < top(2,1)
        rect(1,:) = top(1,:);  % t-left
        rect(2,:) = top(2,:);  % t-right
    else
        rect(1,:) = top(2,:);
        rect(2,:) = top(1,:);
    end

    % Sort b-left and b-right by x
    if bottom(1,1) < bottom(2,1)
        rect(4,:) = bottom(1,:);  % b-left
        rect(3,:) = bottom(2,:);  % b-right
    else
        rect(4,:) = bottom(2,:);
        rect(3,:) = bottom(1,:);
    end
end