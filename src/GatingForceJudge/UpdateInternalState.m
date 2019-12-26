% State = MJ_UpdateInternalState( State)
%
% Updates the internal state that is common to the SimpleMonkey
% and SimpleJudge, e.g. recalculates its reckoning of distance
% to target, direction to target etc.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = UpdateInternalState( State)

    %%%
    %%% FORCE
    %%%
    
    % Task requires "targ_force" Newtons along "targ_angle" dimension
    targ_force = State.trial_config.target(4);
    targ_angle = State.trial_config.target(5)*pi/4;
    
    % Offset angle for ATI positioning
    angle = 3*pi/4; %0.4014; %-pi/6;
    rotation = [cos(angle) -sin(angle); sin(angle) cos(angle)]*State.fdbk.force(1:2)';
    x_rot = rotation(2);
    rot = [ -State.fdbk.force(3), x_rot]; % force in correct coordinate system

    
    % Determine magnitude of force, projected on target Vector
    act_force = norm(rot, 2);
    fprintf('act force: %0.5g \r\n feedback: %0.5g \n', act_force, State.fdbk.force);
    % What is the difference between the angle of the force ad the required
    % angle?
    rotAngle = rad2deg(atan2(rot(2),rot(1)));
    fprintf('Angles: %0.5g \t %0.5g \n', wrapTo360(rotAngle), wrapTo360(rad2deg(targ_angle)));
    
    % If the angle is off by more than 20 degrees set force to 0
    adjAngle = wrapTo360(-rotAngle);
    
    fprintf('Generated Forces: %0.5g \n', act_force);
    
    if abs(rad2deg(targ_angle) - adjAngle) > 45 && abs(rad2deg(targ_angle) - adjAngle) < 315
      act_force = 0;
    end
    
    %act_force = norm(State.fdbk.force(1:3), 2); % wrong
    target_distance = targ_force - abs(act_force);
    
    fprintf('Forces: %0.5g \t %0.5g \n', act_force, targ_force);

    State.calc.force_distance = target_distance;