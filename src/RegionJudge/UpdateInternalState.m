% State = MJ_UpdateInternalState( State)
%
% Updates the internal state that is common to the SimpleMonkey
% and SimpleJudge, e.g. recalculates its reckoning of distance
% to target, direction to target etc.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = UpdateInternalState( State)

angle = State.trial_config.target(5)*pi/4;
State.TargetZone.rotate(angle);

% Is point in region?


State.hasFailed = ~State.TargetZone.inZone(State.fdbk.actual_pos(1),...
            State.fdbk.actual_pos(2),...
            State.fdbk.actual_pos(3));

end