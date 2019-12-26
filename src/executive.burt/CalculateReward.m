%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [amount, valid] = CalculateReward(level)
    
    valid = true;
    if ischar(level)
        if ~isempty(regexp(level, 'e\d+', 'match'))
            amount = strrep(level, 'e', '');
            amount = exprnd(str2double(amount));
        elseif ~isempty(regexp(level, 'N\d+', 'match'))
            amount = strrep(level, 'N', '');
            amount = regexp(amount,'\,','split');
            fprintf('normal reward:\n');
            amount = normrnd(str2double(amount(1)),str2double(amount(2)));         
        else
            amount = str2num(level);
            if isempty(amount)
                amount = 0;
                valid = false;
            end
        end
    else
        amount = level;
    end    