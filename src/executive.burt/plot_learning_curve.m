function [beta_hist h1 h2 h3] = plot_learning_curve(ohist,dhist,runDiff,nextDiff,prevLC,beta_hist)

dbstop if error

max_hist = 10;

h = findobj('Type','Figure','Name','Learning Curve Window');

if(isempty(h))
    h = figure('Name','Learning Curve Window','Units','normalized','Position',[0.65 0.1 0.35 0.75]);
else
end
h1 = subplot(3,1,1);
set(h1,'Tag','Learning Curve History')
h2 = subplot(3,1,2);
set(h2,'Tag','Catch History')
h3 = subplot(3,1,3);
set(h3,'Tag','Actual Performance')

modelfunc = prevLC.modelFun;
b0 = prevLC.orig_beta;
% Get actual numbers for the previous day SR vs. Difficulty curve
prevFit = feval(prevLC.modelFun,prevLC.beta,prevLC.sampDiff);
%last_Diff = prevLC.sampDiff(find(prevFit<0.05,1,'first'));
last_Diff = max(prevLC.sampDiff);

% Fit new curve based on today's data
if(length(dhist)>1)
    temp_inds = max(length(dhist)-50,1):length(dhist);
    %beta_new = nlinfit(dhist,ohist,modelfunc,b0);
    beta_new = nlinfit(dhist(temp_inds),ohist(temp_inds),modelfunc,b0); % Added temp_inds for sliding window curves as in executive
    newFit = feval(prevLC.modelFun,beta_new,prevLC.sampDiff);
else
    beta_new = b0;
    newFit = prevFit;
end

if(~isempty(beta_hist))
    for i=min([length(beta_hist),max_hist-1]):-1:1
        beta_hist(i+1) = beta_hist(i);
    end
end
beta_hist(1) = beta_new;

% Calculate actual percentages for each difficulty;
unique_diffs = unique(dhist);
diff_perf = zeros(size(unique_diffs));
diff_sem_perf = zeros(size(unique_diffs));
for i=1:length(diff_perf)
    diff_inds = find(dhist==unique_diffs(i));
    diff_perf(i) = mean(ohist(diff_inds));
    diff_sem_perf(i) = std(ohist(diff_inds))/length(ohist(diff_inds));
end

% Calculate Catch Trial Probability Distribution to plot again actual
% histogram

% 2nd Derivative combined with 1st Derivative pdf method
d1 = [0 abs(diff(newFit))];
d1 = d1/sum(d1);
d2 = [0 abs(diff(diff(newFit))) 0];
lw = 6;
criti = find(d2 ~= 0,1,'first') - 1;
if isempty(criti)
    criti = 1;
end
if criti+lw > length(d2)
    lw = length(d2)-criti-1;
end
d2(criti:criti+lw) = linspace(d2(criti),d2(criti+lw),lw+1);
d1(criti:criti+lw) = linspace(d1(criti),d1(criti+lw),lw+1);
d2 = d2/sum(d2);
d1 = d1/sum(d1);
d3 = d1+d2;
d3 = d3/sum(d3);


% Plot learning curve fit history
for i=1:length(beta_hist)
        plot(h1,prevLC.sampDiff,feval(prevLC.modelFun,beta_hist(i),prevLC.sampDiff),'b')
hold(h1,'on');
end
plot(h1,prevLC.sampDiff,prevFit,'k')
plot(h1,prevLC.sampDiff,newFit,'r')
stem(h1,nextDiff,1,'k')
hold(h1,'off');
xlim(h1,[[0 last_Diff]])
title(h1,'Learning Curve History')
drawnow

% Plot catch trial histogram
%figure(h2)
counts = histc(dhist(dhist~=runDiff),prevLC.sampDiff);
if(isempty(counts))
    counts = zeros(length(prevLC.sampDiff),1);
end
bar(h2,prevLC.sampDiff,counts)
hold(h2,'on');
plot(h2,prevLC.sampDiff,d1.*max(counts)./max(d1),'b--')
plot(h2,prevLC.sampDiff,d2.*max(counts)./max(d2),'r--')
plot(h2,prevLC.sampDiff,d3.*max(counts)./max(d3),'k--')
stem(h2,nextDiff,max([counts(:); 1]),'k')
hold (h2,'off');
xlim(h2,[[0 last_Diff]])
title(h2,'Catch Diff Histogram')

drawnow

% Plot mean/sem performance at each difficulty
%plot(h3,unique_diffs,diff_perf,'k')
errorbar(h3,unique_diffs,diff_perf,diff_sem_perf,'k')
hold(h3,'on');
xlim(h3,[0 last_Diff])
title(h3,'Performance')
hold(h3,'off');
drawnow
