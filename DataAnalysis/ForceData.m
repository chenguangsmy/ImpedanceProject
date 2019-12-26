%Pre-process the force data to be aligned at movement onset for each
%condition type
if (plotForce == 1)
    figure('Name','Force'); 
end

%FIXME: for some reason can't use block number here for the subplot command?
posByBlock = zeros(forceRows * blocks, maxCols);
onsetIndexByBlock = zeros(1,blocks);
%maxMoveTime = 0;
for i = 1 : blocks
    %per block
    com1indexPerBlock = com1Index(i, :);
    com1indexPerBlock = nonzeros(com1indexPerBlock);
    time = 0 : 0.02 : (length(com1indexPerBlock) -1) * 0.02;
    if (movementOnsetIndex(1,i) == 0)
        %no data for this trial. The current condition didn't go through as
        %many repetitions. Not ideal... ok for now.
        fprintf('No data for combo no: %d, rep: %d\n\n',conditionIndex, i);
        continue
    end
    time0Index = find(com1indexPerBlock == movementOnsetIndex(1,i));
    onsetIndexByBlock (1, i) = time0Index;
    moveTime = length(com1indexPerBlock) - time0Index;
    fprintf('Move Time: %d\n',moveTime);
    %TODO: figure out how to calculate max movetime for all in the
    %beginning
    if (moveTime > maxMoveTime)
       maxMoveTime = moveTime;
    end
    %before alignment, time is different for each rep
    time = time - (time0Index-1) * 0.02;
    pos = dataCurr.Data.Position.Force(:, com1indexPerBlock);
    posSize = size(pos);
    posByBlock((i-1)*forceRows+1 : i*forceRows, 1 : posSize(1, 2)) = pos;
    
    if (plotForce == 1)
        plotIndex = (i-1)*forceRows+1;
        for k = 1:forceRows
            subplot(blocks,forceRows, plotIndex);
            plot(time, pos(k,:));
            plotIndex = plotIndex + 1;
        end
    end
end

if (plotForce == 1)
    figure('Name','Force Aligned at time 0'); 
end

%maxOnsetIndex = max(onsetIndexByBlock);
alignedCols = maxOnsetIndex+maxMoveTime;

%rearrange to be x1-25, y 26-50, z51-75
alignedPosByBlock = NaN(forceRows*blocks, alignedCols);

time = 0 : 0.02 : (alignedCols-1) * 0.02;
time = time - (maxOnsetIndex-1) * 0.02;

for i = 1 : blocks
    time0Index = onsetIndexByBlock(1, i);
    %time stamp padding needed
    offset = maxOnsetIndex - time0Index +1;
    for j = 1 : forceRows
        toFill = posByBlock((i-1)*forceRows + j,:);
        nonzeroCols = length(nonzeros(toFill));
        alignedPosByBlock(i+(j-1) * blocks, offset : offset+nonzeroCols - 1) = toFill(1, 1:nonzeroCols);
    end
    
    if plotForce == 1 
        plotIndex = (i-1)*forceRows+1;
        for k = 1 : forceRows
            subplot(blocks,forceRows, plotIndex);
            plot(time, alignedPosByBlock(i+(k-1)*blocks, :));
            xlim([time(1), time(length(time))]);
            plotIndex = plotIndex + 1;
        end
    end
end


trialAverageData = zeros(forceRows, alignedCols);
if (plotForce == 1)
    figure('Name' ,'Trial Average Force');
end

for i = 1 : forceRows
    trialAverageData(i, :) = mean(alignedPosByBlock((i-1)*blocks+1:i*blocks, :));
    if (plotForce == 1)
        subplot(forceRows,1,i);
        plot(time,trialAverageData(i, :));
    end
end

%Assume a variable for all data exists: 
%TrialAverage: 6 rows per condition;
%Time 1 row per condition; 
%AlignedByBlock: total reps (blocks * rep per block) * 6 rows per condition
%In row order: Fx for all reps of a given condition, y, z, torque x, y, z; 
%then repeat for next condition
%RawBeforeAlignment: not aligned at time 0, in order x,y,z,torque x,y,z for
%1 rep of a given condition; then next rep...; after all reps for this
%condition; starts with rep1 of next condition.
%DataIndex: the index used to locate data ror each successful rep
%1 row corresponds to 1 rep, total rows = rep per condition * conditions.

%starts fill in the data from the first column
AllTrialAverage((conditionType-1)*forceRows+1 : conditionType*forceRows,...
    1:alignedCols) = trialAverageData(:,:);

AllAlignedByBlock((conditionType-1)*blocks*forceRows+1 : conditionType*blocks*forceRows,...
    1:alignedCols) = alignedPosByBlock(:,:);

for i = 1 : blocks*forceRows
    toFill = posByBlock(i,:);
    nonZeroCols = length(nonzeros(toFill));
    AllRaw((conditionType-1)*blocks*forceRows+i,1:nonZeroCols) = posByBlock(i,1:nonZeroCols);
end

for i = 1 : blocks
    nonZeroCols = length(nonzeros(com1Index(i, :)));
    AllDataIndex((conditionType-1)*blocks+i,1:nonZeroCols) = com1Index(i, 1:nonZeroCols);
end

AllTime(conditionType, 1:length(time)) = time;
