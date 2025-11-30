close all
clear all

source = "dataset_orig";
destination = "dataset_final";

D = dir(source.append("\*"));
for i = 3:length(D)
    folder = D(i);
    path = sprintf("%s\\%s\\*", folder.folder, folder.name);
    A = dir(path);
    for j = 3:length(A)
        impath = A(j).folder;
        impath = sprintf("%s\\%s", impath, A(j).name);
        img = imread(impath);
        imsize = size(img);
        as = imsize/3;
        img = img(as:as*2,as:as*2,:);

        gray = rgb2gray(img);
        %imshow(gray)
        
        [centers,radii] = imfindcircles(gray,[50 300],ObjectPolarity="dark", Sensitivity=0.94);
        %h = viscircles(centers,radii);
        if isempty(centers)
            %continue
            sprintf("Image %s couldnt be resolved", impath)
            snipsize = size(img);
            centers = [snipsize(1)/2, snipsize(2)/2];
        end

        %imshow(img)
        %h = drawcircle('Center', centers(1,:), 'Radius', radii(1));
        % bw = rgb2gray(img);
        % h = circles2mask(centers(1,:), radii(1), size(bw));
        % %bw = createMask(h);
        % img = img.*repmat(uint8(h), [1 1 3]);

        cx = centers(1,1);
        cy = centers(1,2);

        padding = 250;
        img = img(cy-padding:cy+padding,cx-padding:cx+padding,:);

        img = imresize(img, [227 227]);
        %contrastAdjustedImg1 = imadjust(img, [], [], 1.5);

        % HSV = rgb2hsv(img);
        % HSV(:, :, 2) = HSV(:, :, 2) * 1.0;
        % img = hsv2rgb(HSV);

        %imshow(contrastAdjustedImg1)
        outpath = replace(impath, source, destination);
        imwrite(img, outpath)
    end
end
