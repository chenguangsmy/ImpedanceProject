% executive( ConfigFile, mm_ip)
%
% ConfigFile is the file name of the main config file that should be
% loaded from the config/ directory
%
% mm_ip is the network address of the MessageManager
%
% Ivana Stevens 8/21/2018
function executive( ConfigFile, mm_ip )

global XM;
global COMMAND_LINE_ARGUMENTS;
global EVENT_MAP;
global RTMA_runtime;

MessageTypes = {...
  'AM_APP_NAME'...
  'APP_ERROR'...
  'BURT_STATUS' ...
  'CHANGE_TOOL_COMPLETE'...
  'CHANGE_TOOL_INVALID'...
  'DENSO_READY'...
  'DENSO_NOT_READY'...
  'DENSO_MOVE_COMPLETE'...
  'DENSO_MOVE_FAILED'...
  'DENSO_MOVE_INVALID'...
  'DENSO_MOVE_CONTINUE' ...
  'DENSO_HALTED'...
  'EM_READY'...
  'EM_FROZEN'...
  'EM_ALREADY_FROZEN'...
  'EM_ADAPT_DONE'...
  'EM_ADAPT_FAILED'...
  'EM_DRIFT_CORRECTED'...
  'EXIT' ...
  'GIVE_REWARD' ...
  'IO_STREAM_STARTED'...
  'IO_STREAM_STOPPED'...
  'JOYPAD_R1'...
  'JOYPAD_X' ...
  'JUDGE_VERDICT'...
  'KEYBOARD'...
  'MESSAGE_LOG_SAVED'...
  'PAUSE_EXPERIMENT' ...
  'PS3_BUTTON_PRESS' ...
  'PS3_BUTTON_RELEASE' ...
  'PROCEED_TO_Failure'...
  'PROCEED_TO_NextState'...
  'PING' ...
  'READY_BUTTON' ...
  'RESUME_EXPERIMENT' ...
  'SAMPLE_GENERATED' ...
  'TIMER_EXPIRED'...
  'TIMED_OUT'...
  'XM_START_SESSION'...
  'XM_ABORT_SESSION'...
  };

% LOAD ENVIRIONMENT VARIABLES
RTMA_BaseDir = getenv('RTMA');
ROBOT_COMMON = getenv('ROBOT_COMMON');

addpath([RTMA_BaseDir '/lang/matlab']);
addpath([ROBOT_COMMON '/Matlab']);
App_IncludeDir = getenv('ROBOTINC');

MessageConfigFile = [App_IncludeDir '/RTMA_config.mat'];
ModuleID = 'EXEC_MOD';

if ~exist( 'ConfigFile', 'var') || isempty(ConfigFile) || strcmpi(ConfigFile, 'none')
  error( 'Missing ConfigFile argument');
end

COMMAND_LINE_ARGUMENTS.ConfigFile = ConfigFile;


ConnectToMMM(0, '', [getenv('ROBOTINC') '/RTMA_config.mat'], '-server_name pfem:7112')
Subscribe( MessageTypes{:})

% Respond to ping, xm_start_sesion, and such
RTMA_runtime.EventHook = @NewMonkeyKnob_EventHook;

%Makes necessary folders and populates global XM
SetupSession();
SendModuleReady();
SendModuleVersion('executive');

disp 'Executive running...'

% Run until all tasks are done
while(1)
  % Run until all reps are done
  while(1)
    SetupTrial();
    num_task_states = length(XM.config.task_state_config.state_names);
    ts = 1;
    while ( ts <= num_task_states )
      try
        task_state_config = GetTaskStateConfig(ts);
        
        fprintf('|%s| ', task_state_config.state_names);
        
        if( task_state_config.skip_state == 1),
          fprintf('skipped\n');
          ts = ts + 1;
          continue;
        end
        
        [target, judge_target] = ChooseTarget( task_state_config);
        
        RunTaskState( task_state_config, target);
        ConfigureTaskState( task_state_config);
        ConfigureJudge( ts, task_state_config, judge_target);
        
      catch ME
        fprintf('\n>>> ERROR: %s\n', ME.message);
        fprintf('\nPlease fix the problem and hit ENTER to continue\n');
        pause;
        ts = num_task_states + 1;   % start a brand new trial
      end
      
      if (ts <= num_task_states)
        try
          RcvEvent = [];
          if ( ~isempty(fieldnames(EVENT_MAP)))
            ExpectedEvents = fieldnames( EVENT_MAP);
            RcvEvent = WaitFor( ts, ExpectedEvents{:});
          end
          
          if( XM.aborting_session)
            disp('Aborting session..');
            break;
          end
          
          [outcome, next_state] = TaskStateEnded( ts,...
            RcvEvent,...
            task_state_config);
          
          % check task_state_config.goto
          if isfield(task_state_config, 'goto')
            switch(outcome)
              case 0  % failed
                if isfield(task_state_config.goto, 'f')
                  val = str2num(task_state_config.goto.f);
                  if ~isempty(val)
                    next_state = val;
                  end
                end
                
              case 1  % success
                if isfield(task_state_config.goto, 's')
                  val = str2num(task_state_config.goto.s);
                  if isnumeric(val)
                    next_state = val;
                  end
                end
            end
          end
          
          if (next_state > 0)
            ts = next_state;
          else
            ts = ts + 1;
          end
          
        catch ME
          fprintf('\n>>> ERROR: %s\n', ME.message);
          fprintf('\nPlease fix the problem and hit ENTER to continue\n');
          pause;
          ts = num_task_states;  % skip to InterTrial state
        end
      end
    end
    InterTrial();
    
    if( isempty( XM.combos_to_be_tried) || XM.aborting_session)
      break;
    end
    
  end
  
  if( (XM.rep_num >= XM.config.num_reps) || XM.aborting_session)
    disp('Finished all reps, will quit now (or someone aborted session)');
    %--- Stop Analog Stream
    SendSignal IO_STOP_STREAM;
    break;
  end
  %     XM.rep_num = XM.rep_num + 1;
  %     if( (XM.rep_num >= XM.config.num_reps) || XM.aborting_session)
  %       XM.rep_num = 0;
  %       break;
  %     end
  %   end
  %
  %   % If completed all trials
  %   if( isempty( XM.combos_to_be_tried) || XM.aborting_session)
  %     break;
  %   end
end

DoExit();
end

%%
function [tgt, jdgTgtPos] = ChooseTarget( tsc)

global XM;
global RTMA;

%
% Determine target
%
tgtConfig = tsc.target_configurations;


tgt_cfg = sprintf('config_%s', tsc.reach_target);
tgt_idx = 1;
if (size(tgtConfig.(tgt_cfg).targets, 1) > 1)
  tgt_idx = tgtConfig.combos.(tsc.reach_target)(XM.active_combo_index);
end

home_cfg = sprintf('config_%s', tsc.center_target);
home_idx = 1;
center =  tgtConfig.(home_cfg).targets(home_idx,:);

% tgtBase(1): index of target direction, 0, 1, 2, ..., 7 = 0, 45, 90, ..., 315 degrees
% tgtBase(2): distance between target and center (in robot coordinates)
tgtBase = tgtConfig.(tgt_cfg).targets(tgt_idx,:);
% target location (X, Y, Z) in robot coordinates relative to center
[tgtX, tgtY, tgtZ] = pol2cart(tgtBase(1)*pi/4, tgtBase(2), 0);


% length(tgt) == 8 + RTMA.defines.MAX_HAND_DIMS
% tgt(1:3): absolute target location in robot coordinates
% tgt(4):   force (N)
% tgt(5:7): [index_of_direction distance force]
% tgt(end-1:end): absolute center location in robot coordinates
hand = zeros(1, RTMA.defines.MAX_HAND_DIMS);
tgt = [-tgtX+center(1) tgtY+center(2) tgtZ+center(3) tgtBase(3) tgtBase 0 hand];
tgt(end-2:end) = center;


jdgTgtPos = tgt;
if isfield(tsc, 'separate_judge_target') && ~strcmp(tsc.separate_judge_target, '-')
  judge_tgt_cfg = sprintf('config_%s', tsc.separate_judge_target);
  judge_tgt_idx = 1;
  if (size(tgtConfig.(judge_tgt_cfg).targets, 1) > 1)
    judge_tgt_idx = tgt_idx;
  end
  judge_tgt = tgtConfig.(judge_tgt_cfg).targets(judge_tgt_idx,:);
  jdgTgtPos(1:3) = judge_tgt(1:3);
  %fprintf('Judge target  : %s,  idx: %d\n', tsc.separate_judge_target, tgt_idx);
end



% tgt_ori_rot_mat = ypr2mat(tgt(4:6));
% if (~strcmp(tsc.use_grasp_ori_offset, '-'))
%     graspOffset = tgtConfig.(hand_cfg).grasp_orientation_offset;
%     offset_ori_rot_mat = ypr2mat(graspOffset);
%     tgt_ori_rot_mat = tgt_ori_rot_mat * offset_ori_rot_mat;
% end
% coriMat = tgt_ori_rot_mat';
% coriMat = coriMat(:)';
end