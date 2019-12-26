% Load the previous learning curve

function Rad2Diff = LoadRad2Diff2D()
    
    R2DDir = '/home/vr/rg2/data/LearningCurveData/Rad2DiffData2D.mat';
    
    load(R2DDir);
    
    Rad2Diff.beta = beta(:);
    Rad2Diff.R = R;
    Rad2Diff.J = J;
    Rad2Diff.CovB = CovB;
    Rad2Diff.MSE = MSE;
    Rad2Diff.ErrorModelInfo = ErrorModelInfo;
    Rad2Diff.sampDiff = sampDiff;
    Rad2Diff.modelFunFwd = modelFunFwd;
    Rad2Diff.modelFunBack = modelFunBack;
    % Rad2Diff.prevSRs = prevSRs;
    
end