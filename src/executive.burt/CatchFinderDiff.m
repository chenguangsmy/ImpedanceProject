% Find the optimal value for the next catch trial

function nextCatchDiff = CatchFinderDiff(ohist,dhist,prevLC,runDiff)

% CatchFinderDiff takes the following as arguments.
% ohist: The history of outcomes of the trials so far (0s and 1s)
% dhist: The difficulty of each trial that has been run so far
% prevLC: The SR vs. Difficulty curve calculated from the previous day
% runDiff: The (closest to) 70% difficulty, picked from prevLC

global XM;

% Define the model that we will be using to fit the SR vs Diff
modelfunc = prevLC.modelFun;
b0 = prevLC.beta;
prevFit = feval(prevLC.modelFun,prevLC.beta,prevLC.sampDiff);

% Figure out how many catch trials have been run so far
nprevcatches = sum(~isnan(dhist(dhist ~= runDiff))); % NOTE:  This only really works before adaptation period since we start altering runDiff afterward.

% Set the initial number of catch trials to run on a fixed sample interval
% ninitial = 20;
ninitial = 10;

% Set the fixed interval for the initial catch trial difficulties
% initialcatches = min(prevLC.sampDiff):range(prevLC.sampDiff)/(ninitial):max(prevLC.sampDiff);
initialcatchesSR = 0.05:1/ninitial:0.95;
initialcatches = nan(size(initialcatchesSR));
for i = 1:length(initialcatchesSR)
    [~,mini] = min(abs(initialcatchesSR(i) - prevFit));
    initialcatches(i) = prevLC.sampDiff(mini);
end

% Set difficulty to the fixed schedule if within ninitial or if not using
% catch finding algorithm.
if ~XM.config.catch_algorithm_on
    disp('Picking catch trial from fixed schedule (SR Space)');
    nextCatchDiff = initialcatches(randi(length(initialcatches)));
    return;
end
if nprevcatches < ninitial
    disp('Picking catch trial from initial fixed spacing');
    nextCatchDiff = initialcatches(nprevcatches+1);
    return;
end

disp('Picking catch trial with online automated re-fit algorithm');
unsort_dhist = dhist;
unsort_ohist = ohist;
[dhist,sortI] = sort(dhist);
ohist = ohist(sortI);

% [oldB,oldDev,oldStats] = glmfit(dhist,ohist,'binomial');

% Fit the current SR vs. Difficulty curve
if XM.rep_num > 15 & XM.rep_num < 40 % Only calc new curve during adaptation window (before = fixed interval schedule, after = fixed LC)
    disp('Calculating new learning curve fit')
    %[thisBeta,~,~,oldCovB,~] = nlinfit(dhist,ohist,modelfunc,b0);
    %temp_inds = max([length(dhist)-50,1]):length(dhist); % Take window of last 40 trials (or entire history if <40 trials)
    
    %[thisBeta,~,~,oldCovB,~] = nlinfit(unsort_dhist(temp_inds),unsort_ohist(temp_inds),modelfunc,b0);
    
    %thisBeta = prevLC.run_beta;
   
    % Get the current uncertainty in curve parameters
    % oldSE = sqrt(diag(oldCovB));
    
    % SEreduc = nan(size(oldSE,1),length(prevLC.sampDiff));
    % scaledSEreduc = nan(size(SEreduc));
    
    % Get actual numbers for the previous day SR vs. Difficulty curve
    %thisFit = feval(modelfunc,thisBeta,prevLC.sampDiff);

else
    disp('Using stationary learning curve fit')
%    thisBeta = b0;
%    thisFit = prevFit;
end

thisBeta = prevLC.run_beta;

% Get actual numbers for the previous day SR vs. Difficulty curve
thisFit = feval(modelfunc,thisBeta,prevLC.sampDiff);
    
% 2nd Derivative combined with 1st Derivative pdf method
d1 = [0 abs(diff(thisFit))];
if(sum(d1)==0)
    disp('Skill difficulty at maximum, picking catch trial from fixed schedule (SR Space)')
    nextCatchDiff = initialcatches(randi(length(initialcatches)));
else
d1 = d1/sum(d1);
d2 = [0 abs(diff(diff(thisFit))) 0];
lw = 6;
criti = find(d2 ~= 0,1,'first') - 1;
if isempty(criti)
    criti = 1;
end
d2(criti:criti+lw) = linspace(d2(criti),d2(criti+lw),lw+1);
d1(criti:criti+lw) = linspace(d1(criti),d1(criti+lw),lw+1);
d2 = d2/sum(d2);
d1 = d1/sum(d1);
d3 = d1+d2;
d3 = d3/sum(d3);
cd3 = zeros(size(d3));
for i = 1:length(d3)
    cd3(i) = sum(d3(1:i));
end
[~,picki] = min(abs(rand - cd3));
nextCatchDiff = prevLC.sampDiff(picki);
end


% % For each of the possible difficulties... (binary method)
% for i = 1:length(prevLC.sampDiff)
%     % Add the hypothetical next difficulty to the history of difficulties
%     newdiffs = [dhist; prevLC.sampDiff(i)];
%     [newdiffs,sortI] = sort(newdiffs);
%     % Add a hypothetical success to the ohist
%     SRwSucc = [ohist; 1];
%     SRwSucc = SRwSucc(sortI);
%     [~,~,~,succCovB,~] = nlinfit(newdiffs,SRwSucc,modelfunc,b0);
%     % Add a hypothetical fail to the ohist
%     SRwFail = [ohist; 0];
%     SRwFail = SRwFail(sortI);
%     [~,~,~,failCovB,~] = nlinfit(newdiffs,SRwFail,modelfunc,b0);
%     
%     % Calculate how much the parameter uncertainty will be reduced in each
%     % case (success or fail)...
%     succReduc = oldSE - sqrt(diag(succCovB));
%     failReduc = oldSE - sqrt(diag(failCovB));
%     % ...and weight them based on the chance of success or failure as
%     % determined by the previous day's SR vs. Difficulty curve
%     SEreduc(:,i) = succReduc*prevFit(i) + failReduc*(1-prevFit(i));
%     % Convert uncertainty reduction to percent uncertainty reduction
%     for j = 1:size(SEreduc,1)
%         scaledSEreduc(j,i) = SEreduc(j,i)/oldSE(j);
%     end
% end

% % For each of the possible difficulties... (straight SR method)
% for i = 1:length(prevLC.sampDiff)
%     % Add the hypothetical next difficulty to the history of difficulties
%     newdiffs = [dhist; prevLC.sampDiff(i)];
%     [newdiffs,sortI] = sort(newdiffs);
%     % Add a hypothetical SR to the ohist
%     SRwNew = [ohist; prevFit(i)];
%     SRwNew = SRwNew(sortI);
%     [~,~,~,NewCovB,~] = nlinfit(newdiffs,SRwNew,modelfunc,b0);
%     
%     % Calculate how much the parameter uncertainty will be reduced in each
%     % case (success or fail)...
%     SEreduc(:,i) = oldSE - sqrt(diag(NewCovB));
%     % Convert uncertainty reduction to percent uncertainty reduction
%     for j = 1:size(SEreduc,1)
%         scaledSEreduc(j,i) = SEreduc(j,i)/oldSE(j);
%     end
% end
% 
% % Choose the difficulty that reduces uncertainty the most
% totReduc = sum(scaledSEreduc,1)
% [~,maxreduc] = max(totReduc);
% nextCatchDiff = prevLC.sampDiff(maxreduc);

