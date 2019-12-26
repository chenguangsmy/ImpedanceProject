% Load the previous learning curve

function PrevLCFit = LoadPrevLearningCurve2D()
    
    LCDir = '/home/vr/rg2/data/LearningCurveData/';
    files = dir([LCDir 'LC.Oops.2D*']);
    file2load = files(end).name;
    
    disp(['Loading ' file2load ' as previous learning curve']);
    load([LCDir file2load]);
    
    PrevLCFit.beta = beta(:);
    PrevLCFit.R = R;
    PrevLCFit.J = J;
    PrevLCFit.CovB = CovB;
    PrevLCFit.MSE = MSE;
    PrevLCFit.ErrorModelInfo = ErrorModelInfo;
    PrevLCFit.sampDiff = sampDiff;
    PrevLCFit.modelFun = modelFun;
    
end