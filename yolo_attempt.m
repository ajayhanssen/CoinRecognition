imds = imageDatastore("archive\images\");

groundim = imread("archive\images\001.jpg");
imgH = size(groundim, 1);
imgW = size(groundim, 2);

labelDir = "archive/labels/";
files = dir(fullfile(labelDir, '*.txt'));

bboxData  = cell(length(files), 1);
labelData = cell(length(files), 1);

for i = 1:length(files)
    textfile = fullfile(labelDir, files(i).name);
    
    data = readmatrix(textfile);
    classes = data(:,1);
    xc = data(:,2);
    yc = data(:,3);
    w = data(:,4);
    h = data(:,5);

    x = (xc - w/2) * imgW;
    y = (yc - h/2) * imgH;
    width  = w * imgW;
    height = h * imgH;

    bboxes = [x y width height];
    bboxData{i} = bboxes;
    %labelData{i} = categorical(classes);
    labelData{i} = arrayfun(@num2str, classes, 'UniformOutput', false); % CHANGE HERE
end

tbl = table(imds.Files, bboxData, labelData);
tbl.Properties.VariableNames = {'imageFilename', 'box', 'label'}

%% Datastores und vis
imds = imageDatastore(tbl{:,"imageFilename"});
%blds = boxLabelDatastore(tbl(:,'label'))
blds = boxLabelDatastore(tbl(:,{'box', 'label'}));
trainingData = combine(imds, blds); % imageds und blds zammstopseln

preview(trainingData)

data = read(trainingData);

I = data{1};
bbox = data{2};
label = data{3};
positions = bbox(:,1:2); % alle zeilen, erste zweite spalte sind x und y
labelStrings = cellstr(label);

annotatedImage = insertShape(I,"Rectangle",bbox);
annotatedImage = insertText(annotatedImage, positions, labelStrings, ...
    'FontSize', 16, 'BoxOpacity', 0.6);
annotatedImage = imresize(annotatedImage,2);
figure
imshow(annotatedImage)

%% preprocess, anchorboxes
inputSize = size(groundim);
inputSize = [416 416 3];

trainingDataForEstimation = transform(trainingData,@(tbl)preprocessData(tbl,inputSize));

numAnchors = 6;
[anchors,meanIoU] = estimateAnchorBoxes(trainingDataForEstimation,numAnchors);
area = anchors(:,1).*anchors(:,2);
[~,idx] = sort(area,"descend");
anchors = anchors(idx,:);
anchorBoxes = {anchors(1:3,:);anchors(4:6,:)};


allLabels = [];

reset(blds)
while hasdata(blds)
    data = read(blds);
    allLabels = [allLabels; data{:,2}];   % column 2 = label column
end

uniqueClasses = unique(allLabels);

%% detector
%classes = ["box"];
classes = string(0:7); % CHANGE HERE - ["0", "1", "2", "3"]

%detector = yolov4ObjectDetector("tiny-yolov4-coco")
detector = yolov4ObjectDetector("tiny-yolov4-coco",classes,anchorBoxes,InputSize=inputSize);

detClasses = detector.ClassNames % CHANGE HERE - only logging

options = trainingOptions("sgdm", ...
    InitialLearnRate=0.001, ...
    MiniBatchSize=16, ...
    MaxEpochs=40, ...
    ResetInputNormalization=false, ...
    VerboseFrequency=30, ...
    ExecutionEnvironment="gpu");
trainedDetector = trainYOLOv4ObjectDetector(trainingData,detector,options);

function data = preprocessData(data,targetSize)
    for num = 1:size(data,1)
        I = data{num,1};
        imgSize = size(I);
        bboxes = data{num,2};
        I = im2single(imresize(I,targetSize(1:2)));
        scale = targetSize(1:2)./imgSize(1:2);
        bboxes = bboxresize(bboxes,scale);
        data(num,1:2) = {I,bboxes};
    end
end