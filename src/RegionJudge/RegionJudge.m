function RegionJudge(config_filename, mm_ip)
dbstop if error;

DragonflyPath = getenv('RTMA');
CommonPath = getenv('ROBOT_COMMON');
IncludePath = getenv('ROBOTINC');

addpath([DragonflyPath '/lang/matlab']);
addpath([CommonPath '/Matlab']);

DragonflyConfigFile = [IncludePath '/RTMA_config.mat'];
ConnectArgs = {'REGION_JUDGE', '', DragonflyConfigFile};
if exist('mm_ip','var') && ~isempty(mm_ip)
  ConnectArgs{end+1} = ['-server_name ' 'pfem:7112']; %mm_ip];
end
ConnectToMMM(ConnectArgs{:});

Subscribe FORCE_SENSOR_DATA
Subscribe TASK_STATE_CONFIG
Subscribe END_TASK_STATE
Subscribe BURT_STATUS
Subscribe EXIT
Subscribe PING

disp('RegionJudge running...');

State = InitJudge();

while(1)
  M = ReadMessage( 1);
  if isempty(M)
    %disp('.');
    
  else
    switch( M.msg_type)
      case 'TASK_STATE_CONFIG'
        State.trial_config = M.data;
        State.event_occurred = false;
        fprintf('\nC(%i,tout=%.0f)\n', M.data.id, M.data.timeout);
        
      case 'END_TASK_STATE'
        State = ResetState(State);
        fprintf('E(%d)\n', M.data.id);
        
        
% this message is already sampled, no need to use SAMPLED_GENERATED
      case 'BURT_STATUS'
        if( ~State.event_occurred && ~isempty(State.trial_config) && State.trial_config.id == 4 )
          State.fdbk.actual_pos = [M.data.pos_x, M.data.pos_y, M.data.pos_z];
          State = UpdateInternalState( State );
          State = JudgeWhetherEventOccurred( State);
        end

      case 'PING'
        RespondToPing(M, 'RegionJudge');
        
      case 'EXIT'
        if (M.dest_mod_id == GetModuleID()) || (M.dest_mod_id == 0)
          SendSignal EXIT_ACK
          break;
        end
        
    end
  end
end

fprintf( 'Exiting... ')
DisconnectFromMMM
exit

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = JudgeWhetherEventOccurred( State)

global RTMA;

reason = [];

%
% Judging failure
%

% Inform XM if judging is done
if State.hasFailed
  reason = 'THRESHOLD_FAIL';
  msg = RTMA.MDF.JUDGE_VERDICT;
  msg.id = State.trial_config.id;
  msg.reason(1:length(reason)) = int8(reason);
  SendMessage( 'JUDGE_VERDICT', msg);
  
  State = ResetState(State);
  
  fprintf('%s\n', reason);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = ResetState(State)
State.trial_config = [];
State.hasFailed = false;
State.fdbk = [];
State.engaged = false;
State.event_occurred = false;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitJudge()
State = struct();
State = ResetState(State);
width = .15;
State.TargetZone = TargetZone(-0.12, 0.5, 0.25, width, 100, .03, .05);

% threshold_judging_polarity:
% 1=target less than threshold [<] (default)
% 2=target greater than threshold [>]
State.tjp = {'less_than', 'greater_than'};
State.config = [];