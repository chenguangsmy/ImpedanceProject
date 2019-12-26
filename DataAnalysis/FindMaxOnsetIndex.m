%consider only auto success for now, later figure out how to 
%fill in the indices of the manual success ones without repetition
successTrials = find(dataCurr.Data.OutcomeMasks.Success == 1);

trialBegin = -1;
maxOnsetIndex = 0;
maxMoveTime = 0;
trialNo = dataCurr.Data.TrialNo(successTrials(1));
for i = successTrials
%     t = dataCurr.Data.TrialNo(i);
%     if (t~=trialNo)
%         endIndex =  i - 1;
%         moveTime = endIndex - onset + 1;
%         if (moveTime > maxMoveTime)
%             maxMoveTime = moveTime;
%         end
%     end
    
    if (dataCurr.Data.TaskStateCodes.Values(i) == 1 && trialBegin == -1)
        trialBegin = i;
        trialNo = dataCurr.Data.TrialNo(i);
    end
    if (dataCurr.Data.TaskStateCodes.Values(i) == movementOnsetState && trialBegin ~= -1)
        onset = i - trialBegin + 1; %include the first index
        if (onset > maxOnsetIndex)
            maxOnsetIndex = onset;
        end
        trialBegin = -1;
    end
end
fprintf('OnsetIndexMax:%d\n',maxOnsetIndex);
fprintf('MaxMoveTime:%d\n',maxMoveTime);
