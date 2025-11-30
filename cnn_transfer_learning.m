%load("nnet_google.mat")
load("squeezenet.mat")

inputSize = [224 224 3];
imds = imageDatastore("dataset_final\", ...
    "IncludeSubfolders",true, ...
    "LabelSource", "foldernames");

numImages = numel(imds.Labels);
idx = randperm(numImages,16);
I = imtile(imds,Frames=idx);
figure
imshow(I)
%%

classNames = categories(imds.Labels);
numClasses = numel(classNames)
%%
[imdsTrain,imdsValidation,imdsTest] = splitEachLabel(imds,0.7,0.15,0.15,"randomized");

% Image Augmentaiton
pixelRange = [-10 10];
imageAugmenter = imageDataAugmenter( ...
    RandXTranslation=pixelRange, ...
    RandYTranslation=pixelRange, ...
    RandRotation=[0 2*pi], ...
    RandScale=[1 1.2]);

augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    DataAugmentation=imageAugmenter);

augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation);
augimdsTest = augmentedImageDatastore(inputSize(1:2),imdsTest);

%% TRAIN
options = trainingOptions("adam", ...
    InitialLearnRate=0.0001, ...
    MaxEpochs=8, ...
    ValidationData=augimdsValidation, ...
    ValidationFrequency=5, ...
    MiniBatchSize=11, ...
    Plots="training-progress", ...
    Metrics="accuracy", ...
    Verbose=false, ...
    ExecutionEnvironment="gpu");

net = trainnet(augimdsTrain,net_1,"crossentropy",options);

%%
%analyzeNetwork(net)
%tabulate(imdsTrain.Labels)

%% test

YTest = minibatchpredict(net,augimdsTest);
YTest = scores2label(YTest,classNames);

TTest = imdsTest.Labels;
figure
confusionchart(TTest,YTest);

test_im = imread("dataset_final\10_cent\IMG20251129154445.jpg");
test_im = imresize(test_im, [227 227]);
imshow(test_im)
test_im = im2single(test_im);
score = predict(net, test_im)
scores2label(score, classNames)