clear all
close all

img = imread("images\coins3.jpeg");
unwarped = un_warp_sudoku(img);

figure(1)
imshow(unwarped)

function unwarped = un_warp_sudoku(image)
    % Save original image
    %imwrite(image, 'presentation/1_original.jpg');

    % Convert to grayscale
    gray = rgb2gray(image);

    % Apply Gaussian blur
    blurred = imgaussfilt(gray, 1);  % σ=1 roughly matches OpenCV’s (5x5, σ≈1.4)

    % Apply Canny edge detection
    edges = edge(blurred, 'Canny', [0.1 0.3]);  % thresholds can be tuned

    % Find contours (boundaries)
    [B, L] = bwboundaries(edges, 'noholes');

    % Compute area for each contour
    stats = regionprops(L, 'Area');
    [~, idx] = sort([stats.Area], 'descend');

    sudoku_contour = [];

    % Loop through contours looking for a 4-corner polygon
    for i = idx
        contour = B{i};
        % Approximate polygon (Douglas-Peucker)
        epsilon = 0.02 * arcLength(contour, true);
        approx = reducem(contour, epsilon);

        if size(approx, 1) == 4
            sudoku_contour = approx;
            break;
        end
    end

    if isempty(sudoku_contour)
        disp('No valid Sudoku contour found!');
        unwarped = [];
        return;
    end

    % Order points (top-left, top-right, bottom-right, bottom-left)
    rect = order_points(sudoku_contour);

    max_width = 450;
    max_height = 450;

    % Destination points for warp
    dst = [0, 0;
           max_width - 1, 0;
           max_width - 1, max_height - 1;
           0, max_height - 1];

    % Compute perspective transform
    tform = fitgeotrans(rect, dst, 'projective');

    % Warp image
    unwarped = imwarp(image, tform, 'OutputView', imref2d([max_height, max_width]));
end

% --- Helper functions ---

function len = arcLength(contour, closed)
    diffs = diff(contour);
    len = sum(sqrt(sum(diffs.^2, 2)));
    if closed
        len = len + norm(contour(1,:) - contour(end,:));
    end
end

function rect = order_points(pts)
    % Reorder four points in consistent order
    s = sum(pts, 2);
    diff = diff(pts, 1, 2);
    rect = zeros(4, 2);
    rect(1,:) = pts(find(s == min(s)), :); % top-left
    rect(3,:) = pts(find(s == max(s)), :); % bottom-right
    rect(2,:) = pts(find(diff == min(diff)), :); % top-right
    rect(4,:) = pts(find(diff == max(diff)), :); % bottom-left
end
