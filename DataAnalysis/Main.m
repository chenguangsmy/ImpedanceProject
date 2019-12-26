%combo number in order: right (x-), left, top(y+ from 0.5), down(- from 0.5),
%Pos not symmetrical around 0, x is around -0.12, and y is around 0.5
%longer distance -> shorter
%force levels: low, mid high
%array of size 5: 1,3,5,7,9

%TODO: change session number each time
close all;
clear all;
sessionNum = '00189';
fileName = append('Sonic.',sessionNum, '.mat');

%load data
dataCurr = load(fileName);

%set up the condition index array
allConditionIndex = zeros(24,5);
for i = 1:12
    for j = 1:2
        allConditionIndex((i-1)*2+j,:) = (i-1)*10 + j : 2 : i*10;
    end
end

%set up global variable about if plot will be shown

%fixed for current design
%initialize global variables
% global forceRows totalConditionTypes conditionIndex movementOnsetState ...
%     repPerBlock maxCols numberBlocks blocks initPlot plotPos plotForce; 

initPlot = 0;
plotPos = 0;
plotForce = 0;

forceRows= 6;
totalConditionTypes = 24;
maxCols = 1000;
repPerBlock = 5;
movementOnsetState = 4;
%TODO: manually set based on the expeirment, only use complete blocks.
numberBlocks = dataCurr.Data.BlockNo(length(dataCurr.Data.BlockNo)) - 1;

%total repititions of one condition. block number * repPerBlock
%FIXME: for some reason can't use block number read from the array data for the subplot command?
blocks = numberBlocks * repPerBlock;

%initialize output variables:
AllTrialAverage = zeros(forceRows * totalConditionTypes, maxCols);
AllAlignedByBlock = zeros (forceRows * totalConditionTypes * blocks, maxCols);
AllRaw = zeros (forceRows * totalConditionTypes * blocks, maxCols);

%initialize time and data index with NaN since real data couldn't take NaN
AllDataIndex = NaN (totalConditionTypes * blocks, maxCols);
AllTime = NaN(totalConditionTypes, maxCols);

FindMaxOnsetIndex

for conditionType = 1:24
    fprintf('Processing Condition: %d\n',conditionType);
    conditionIndex = allConditionIndex(conditionType,:);
    %validate if block number is different than 5, needs to change the code
    CheckDirectionReading
%     PositionData
    ForceData
    %close all  
end

outputFileName = append('Sonic', sessionNum,'ForceData-AllAligned.mat');
save(outputFileName, 'AllTrialAverage', 'AllAlignedByBlock', 'AllRaw', 'AllDataIndex', 'AllTime');

load(outputFileName);

PlotForceData;