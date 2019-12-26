%function CheckDirectionReading(sessionNumber)

%index by block#, combo#, then time index for corresponding ones, 
com1Index = zeros(blocks,maxCols);
%1 onset time for each repition
movementOnsetIndex = zeros(1, blocks);
conPerBlockIndex = 1;

for i = successTrials
    check = find(conditionIndex == dataCurr.Data.ComboNo(i));
    if (~isempty(check))
        blockNum = dataCurr.Data.BlockNo(i);
        if (blockNum > numberBlocks)
            %skip the incomplete blocks
            continue
        end
        indexToUpdate = (blockNum -1)*repPerBlock + check(1,1);
        %only update the first appearance of state 4 (check for 0 to update
        %it only once)
        if (movementOnsetIndex(1,indexToUpdate) == 0 &&...
                dataCurr.Data.TaskStateCodes.Values(i) == movementOnsetState)
            movementOnsetIndex(1,indexToUpdate) = i;
        end
        for j = 1:maxCols
         if (com1Index(indexToUpdate,j) == 0)
             com1Index(indexToUpdate,j) = i;
             break;
         end
        end
    end
end

%Initial Visual to check how many trials are present for this condition
%And if each trial went through the correct 1-7 states
if (initPlot == 1) 
    temp = nonzeros(com1Index);
    temp = sort(temp);
    com1States = dataCurr.Data.TaskStateCodes.Values(temp);
    figure;
    subplot(2,1,1);
    stateP = plot(com1States);
    title('States');

    com1Trials = dataCurr.Data.TrialNo(temp);
    subplot(2,1,2);
    TrialsP = plot(com1Trials);
    title('Trial Number');
end


