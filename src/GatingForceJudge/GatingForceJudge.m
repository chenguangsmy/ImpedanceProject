function GatingForceJudge(config_filename, mm_ip)

dbstop if error;

DragonflyPath = getenv('RTMA');
CommonPath = getenv('ROBOT_COMMON');
IncludePath = getenv('ROBOTINC');

addpath([DragonflyPath '/lang/matlab']);
addpath([CommonPath '/Matlab']);

DragonflyConfigFile = [IncludePath '/RTMA_config.mat'];
ConnectArgs = {'GATING_JUDGE', '', DragonflyConfigFile};
if exist('mm_ip','var') && ~isempty(mm_ip)
  ConnectArgs{end+1} = ['-server_name ' 'pfem:7112']; %mm_ip];
end
ConnectToMMM(ConnectArgs{:});

Subscribe FORCE_SENSOR_DATA
Subscribe TASK_STATE_CONFIG
Subscribe END_TASK_STATE
Subscribe EXIT
Subscribe PING

disp('GatingForceJudge running...');

State = InitJudge();

while(1)
  M = ReadMessage( 1);
  if isempty(M)
    %disp('.');
    
  else
    switch( M.msg_type)
      case 'TASK_STATE_CONFIG'
        State.trial_config = M.data;
        State.force_gateable = (State.trial_config.id == 3);
        fprintf('C(%d)\n', M.data.id);
        
      case 'END_TASK_STATE'
        State = ResetState(State);
        fprintf('E(%d)\n', M.data.id);
        
        
% this message is already sampled, no need to use SAMPLED_GENERATED
      case 'FORCE_SENSOR_DATA'
        if  (~isempty(State.trial_config) && State.force_gateable )
          State.fdbk.force = M.data.data;
          State = UpdateInternalState( State );
          State = JudgeForceFeedback( State );
        end        
        
      case 'PING'
        RespondToPing(M, 'GatingForceJudge');        
        
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
function State = JudgeForceFeedback( State)

global RTMA;

reason = [];


num_thresholds = 1 ;

targets = [ State.calc.force_distance ];

%
% Judging success
%
judge_s = zeros(1, num_thresholds);
ignore_s = logical(judge_s);

thresh_s = [State.trial_config.sep_threshold];

judging_s_polarity = {State.tjp{1}};

for j = 1 : num_thresholds
  fh = str2func(judging_s_polarity{j});
  if (isnan(thresh_s(j)))
    judge_s(j) = 1;
    ignore_s(j) = 1;
  elseif ( fh(targets(j), thresh_s(j)) )
    judge_s(j) = 1;
  else
    judge_s(j) = 0;
  end
end

% do we have at least one dimension to judge?
if (sum(ignore_s) ~= num_thresholds)
  judge_s(ignore_s) = 0;
  num_judged = length(find(ignore_s == 0));
  
  if (sum(judge_s) == num_judged)
    reason = 'THRESHOLD';
  end
end


%
% Judging failure
%
judge_f = zeros(1, num_thresholds);
ignore_f = logical(judge_f);
thresh_f = [State.trial_config.sep_threshold_f ];

judging_f_polarity = {State.tjp{State.trial_config.sep_threshold_f_judging_polarity} };

for j = 1 : num_thresholds
  fh = str2func(judging_f_polarity{j});
  if isnan(thresh_f(j))
    ignore_f(j) = 1;
  else
    judge_f(j) = fh(targets(j), thresh_f(j));
  end
end

% do we have at least one dimension to judge?
if (sum(ignore_f) ~= num_thresholds)
  if any(judge_f)
    reason = 'FORCE_THRESHOLD_FAIL';
  end
end

% display info
res = repmat({''}, 1, num_thresholds);
iii = find(ignore_s==0);
suc_ = find(judge_s(iii)>0);
suc = iii(suc_);
pol.less_than = '<';
pol.greater_than = '>';
if ~isempty(suc), res(suc) = repmat({'S'}, 1, length(suc));  end
jjj = find(ignore_s==1 & ignore_f==1);
res(jjj) = repmat({'-'}, 1, length(jjj));
fprintf('\n-------------------------------\n');
fprintf('dist     =>   '); fprintf(' %-7.3f   ', targets);  fprintf('\n');

fprintf('thresh_s =>   ');
for i = 1 : num_thresholds
  s_polarity = pol.(judging_s_polarity{i});
  if ignore_s(i), s_polarity = ' '; end
  fprintf('%s%-7.3f   ', s_polarity, thresh_s(i));
end;

fprintf('\nthresh_f =>   ');
for i = 1 : num_thresholds
  f_polarity = pol.(judging_f_polarity{i});
  if ignore_f(i), f_polarity = ' '; end
  fprintf('%s%-7.3f   ', f_polarity, thresh_f(i));
end;

fprintf('\njudging  =>   ');
for i = 1 : num_thresholds, fprintf('    %s     ', res{i});   end;
fprintf('\nverdict  =>   %s\n', reason);

fprintf('\nTO: %.0f  ', State.trial_config.timeout);
fprintf('IDTO: %.0f\n\n', State.trial_config.idle_timeout);


% Inform XM if judging is done
if ~isempty( reason)
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
State.force_gateable = [];
State.fdbk = [];
State.engaged = false;
State.event_occurred = false;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitJudge()
State = struct();
State = ResetState(State);
% threshold_judging_polarity:
% 1=target less than threshold [<] (default)
% 2=target greater than threshold [>]
State.tjp = {'less_than', 'greater_than'};
State.config = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = less_than(target, threshold)
res = target < threshold;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = greater_than(target, threshold)
res = target > threshold;

