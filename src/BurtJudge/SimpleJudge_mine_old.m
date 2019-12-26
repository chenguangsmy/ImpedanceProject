% SimpleJudge
%
% An RTMA module that judges whether a task event has occurred
% on an instantanous basis, such as whether the target has been
% achieved.
%
% A note about UNITS: This module works with angles in radians
% internally.

function SimpleJudge(config_file, mm_ip)

dbstop if error;

global RTMA;

RTMAPath = getenv('RTMA');
SourcePath = getenv('ROBOTSRC');
CommonPath = getenv('ROBOT_COMMON');
IncludePath = getenv('ROBOTINC');

addpath([RTMAPath '/lang/matlab']);
addpath([CommonPath '/Matlab']);

RTMAConfigFile = [IncludePath '/RTMA_config.mat'];
ConnectArgs = {'TASK_JUDGE', '', RTMAConfigFile};
if exist('mm_ip','var') && ~isempty(mm_ip)
  ConnectArgs{end+1} = ['-server_name ' mm_ip];
end
ConnectToMMM(ConnectArgs{:})

Subscribe SAMPLE_GENERATED
Subscribe TASK_STATE_CONFIG
Subscribe ROBOT_CONTROL_SPACE_ACTUAL_STATE
Subscribe GROBOT_SEGMENT_PERCEPTS
Subscribe BURT_STATUS
Subscribe IDLE
Subscribe EXIT
Subscribe PING

State = InitJudge();

IdleState = 0;

disp('SimpleJudge running...');

while(1)
  M = ReadMessage( 1);
  if(isempty(M))
    %fprintf('.')
  else
    switch( M.msg_type)
      
      case 'IDLE'
        IdleState = M.data.idle;
        
      case 'SAMPLE_GENERATED'
        if( ~State.event_occurred && ~isempty(State.trial_config))
          timestep = M.data.sample_header.DeltaTime * 1000;
          
          if ~isnan(State.trial_config.idle_timeout) && (IdleState == 1)
            State.trial_config.idle_timeout =...
              State.trial_config.idle_timeout - timestep;
          else
            State.trial_config.timeout =...
              State.trial_config.timeout - timestep;
          end
          
          if (State.trial_config.idle_timeout <= 0)
            msg = RTMA.MDF.JUDGE_VERDICT;
            msg.id = State.trial_config.id;
            text = 'IDLE_TIMEOUT';
            msg.reason = [ int8(str2num(sprintf('%d ', text))),...
              zeros(1, 64-length(text)) ];
            SendMessage( 'JUDGE_VERDICT', msg);
            State = ResetState(State);
            fprintf('%s\n', text);
            
          elseif (State.trial_config.timeout <= 0)
            msg = RTMA.MDF.JUDGE_VERDICT;
            msg.id = State.trial_config.id;
            text = 'TIMED_OUT';
            msg.reason = [int8(str2num(sprintf('%d ', text))) zeros(1, 64-length(text))];
            SendMessage( 'JUDGE_VERDICT', msg);
            State = ResetState(State);
            fprintf('%s\n', text);
          end
        end
        
      case 'TASK_STATE_CONFIG'
        State.trial_config = M.data;
        State.trialManager = initTargetZone();
        State.event_occurred = false;
        fprintf('\nC(%i,tout=%.0f)\n', M.data.id, M.data.timeout);
        
%       case 'ROBOT_CONTROL_SPACE_ACTUAL_STATE'
%         if( ~State.event_occurred && ~isempty(State.trial_config) )
%           State.fdbk.actual_pos = M.data.pos;
%           State = UpdateInternalState( State);
%           State = JudgeWhetherEventOccurred( State);w
%         end
        
      case 'DENSO_MOVE_COMPLETE'
        stateName = State.trial_config.state_name;
        if strcmp(State.trial_config.reach_target, 'home') && ...
            (strcmp(stateName, 'Reset') || strcmp(stateName, 'Begin'))
          reason = 'TIMED_OUT';
          msg = RTMA.MDF.JUDGE_VERDICT;
          msg.id = State.trial_config.id;
          msg.reason(1:length(reason)) = int8(reason);
          SendMessage( 'JUDGE_VERDICT', msg);
        end
        
      case 'BURT_STATUS'
        if( ~State.event_occurred && ~isempty(State.trial_config) )
          State.fdbk.actual_posX = M.data.pos_x;
          State.fdbk.actual_posY = M.data.pos_y;
          State.fdbk.actual_posZ = M.data.pos_z;
          State.fdbk.actual_forX = M.data.force_x;
          State.fdbk.actual_forY = M.data.force_y;
          State.fdbk.actual_forZ = M.data.force_z;
          State.forceThresholdMet = M.data.state;
          State = UpdateInternalState( State );
          State = JudgeWhetherEventOccurred( State);
        end
        
      case 'PING'
        RespondToPing(M, 'SimpleJudge');
        
        
      case 'RELOAD_CONFIGURATION'
        config = LoadModuleConfigFile(config_file);
        
      case 'EXIT'
        if (M.dest_mod_id == GetModuleID()) || (M.dest_mod_id == 0)
          SendSignal EXIT_ACK
          break;
        end
        
    end
  end
end
DisconnectFromMMM
exit
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = initTargetZone(State)

targetWidth = State.targetWidth;
trackLength = State.trackLength;
errorLimit = State.errorLimit;
State.trialMananger(x,y,z, targetWidth, trackLength*2, errorLimit)

angle = -State.trial_config.direction * PI / 4.0;
%force = task_state_data.force;
width = trackLength / State.trial_config.target_width;

State.trialManager.rotate(angle)
State.trialManager.setTarget(distance, width)
State.trialManager.rotate(angle)


end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = ResetState(State)
State.event_occurred = true;
State.targetWidth = 0.28125;
State.trackLength = 0.53125;
State.errorLimit = 0.008;
State.conversion_factor = 1280/0.2;
State.targetReached = false;
State.trialManager = [];
State.trial_config = [];
State.calc = [];
State.fdbk = [];
State.fdbk.percepts = zeros(1,15);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitJudge()
State = struct();
State = ResetState(State);

% finger_threshold_judging_method:
% 1=distance (default), 2=absolute
State.ftjm = {'finger_target_distance', 'finger_target_absolute'};

% threshold_judging_polarity:
% 1=target less than threshold [<] (default)
% 2=target greater than threshold [>]
State.tjp = {'less_than', 'greater_than'};

State.config = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = JudgeWhetherEventOccurred( State )

global RTMA;

reason = [];

if (State.calc.inZone == false)
  reason = 'THRESHOLD_FAIL';
elseif (State.calc.inTarget == false && State.trial_config.id == 5)
  reason = 'THRESHOLD_FAIL';
elseif (State.forceThresholdMet && State.trial_config.id == 3 )
  reason = 'THRESHOLD';
end


fprintf('\nverdict  =>   %s\n', reason);
fprintf('\nTO: %.0f  ', State.trial_config.timeout);
fprintf('IDTO: %.0f\n\n', State.trial_config.idle_timeout);


% Inform XM if judging is done
if ~isempty( reason)
  msg = RTMA.MDF.JUDGE_VERDICT;
  msg.id = State.trial_config.id;
  msg.reason(1:length(reason)) = int8(reason);
  SendMessage( 'JUDGE_VERDICT', msg);  
  fprintf('%s\n', reason);
end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = less_than(target, threshold)
res = target < threshold;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = greater_than(target, threshold)
res = target > threshold;
end
