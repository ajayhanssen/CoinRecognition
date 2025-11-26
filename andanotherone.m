clear all
close all
dina4 = [210,297];

img = imread("images/coins1.jpg");
gray = rgb2gray(img);
gray = imgaussfilt(gray, 2); 

%imshow(gray)

edges = edge(gray, 'canny');

[H, theta, rho] = hough(edges);
peaks = houghpeaks(H, 10, 'Threshold', 0.3*max(H(:)));
lines = houghlines(edges, theta, rho, peaks, 'FillGap', 20, 'MinLength', 100)'

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

hold off;