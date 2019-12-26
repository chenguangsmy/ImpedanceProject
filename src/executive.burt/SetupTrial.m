function SetupTrial()

global XM;
global RTMA;

target_configurations = XM.config.task_state_config.target_configurations;
fprintf('\n');

% Tell EM to reload its configuration file
msg = RTMA.MDF.RELOAD_CONFIGURATION;
SendMessage('RELOAD_CONFIGURATION', msg);

%--- increment the trial number and attempted start number
XM.trial_num = XM.trial_num + 1; % Increment the count of trial numbers

% Reset the flag that tells the later task states whether the
%monkey succeeded at starting a trial
XM.trial_started = false;

CallFailSafe('LoadXMConfigFile', XM.config_file_name);

% if recevied num_reps from XM_START_SESSION msg, use it
if ~isempty(XM.num_reps)
  XM.config.num_reps = XM.num_reps;
end

% Rest Trials
% if XM.config.do_rest_trials
%   XM.insert_rest_state = false;
%   fprintf('rest_freq_reps %d  rest_trials_per_rep %d \n',...
%     XM.config.rest_freq_reps, XM.config.rest_trials_per_rep)
%   fprintf(' Mod = %d \n',XM.rep_num)
%
%   % Check if we're at the right rep increment for a series of rest trials
%   if(mod(XM.rep_num,XM.config.rest_freq_reps)==0 && XM.rep_num>0)
%
%     % Check if we're done with this rep and can start a rest trial
%     if(isempty(XM.combos_to_be_tried))
%
%       % Check how many rest trials we've already done for this rep.
%       if(XM.rest_trial_num < XM.config.rest_trials_per_rep)
%         XM.insert_rest_state = true;
%         fprintf('Insert_rest_state = true\n')
%         XM.rest_trial_num = XM.rest_trial_num+1;
%         rest_state_config_file = XM.config.rest_state_config_file{1};
%
%         DisplayMessageToUser(['--- Using resting state config file: ' rest_state_config_file]);
%         fprintf('\n======= [ Trial #%d, Rep #%d ] =======\n', XM.trial_num, XM.rep_num);
%         fprintf('\nDoing rest trial #%d of #%d ....\n', XM.rest_trial_num,XM.config.rest_trials_per_rep);
%
%         %--- Reload rest configuration files, so we can do live updates
%         CallFailSafe('LoadTaskStateConfigFile', rest_state_config_file);
%
%       % We've done all our rest trials for this rep, increment rep
%       % number and reset rest trial counter
%       else
%         Xm.insert_rest_state = false;
%         XM.rest_trial_num = 0;
% %         XM.rep_num = XM.rep_num + 1;
%       end
%     end
%   end
% end

XM.insert_alternate_state = false;
if isfield(XM.config, 'alternate_occurrence_freq')
  if ~isfield(XM.config, 'alternate_occurrence_rep') || ...
      (isfield(XM.config, 'alternate_occurrence_rep') && (XM.rep_num >= XM.config.alternate_occurrence_rep))
    if (rand < XM.config.alternate_occurrence_freq)
      [prob_list, orig_idx] = sort(XM.config.alternate_state_config_freq);
      prob = rand;
      for c = 1 : length(prob_list)
        if (prob <= sum(prob_list(1:c)))
          alt_file_idx = orig_idx(c);
          break;
        end
      end
      alternate_state_config_file = XM.config.alternate_state_config_files{alt_file_idx};
      
      %DisplayMessageToUser(['--- Using alternate state config file: ' alternate_state_config_file]);
      
      %--- Reload all configuration files, so we can do live updates
      CallFailSafe('LoadTaskStateConfigFile', alternate_state_config_file);
      
      XM.insert_alternate_state = true;
    end
  end
end


% We don't want to mess with the combos tried/alternate state stuff
% if we're in the middle of rest trials
% if ~XM.insert_rest_state
%   % Alternate trials
%   if isfield(XM.config, 'alternate_occurrence_freq')
%     if ~isfield(XM.config, 'alternate_occurrence_rep') || ...
%         (isfield(XM.config, 'alternate_occurrence_rep') &&  ...
%         (XM.rep_num >= XM.config.alternate_occurrence_rep))
%       if (rand < XM.config.alternate_occurrence_freq)
%         [prob_list, orig_idx] = sort(XM.config.alternate_state_config_freq);
%         prob = rand;
%         for c = 1 : length(prob_list)
%           if (prob <= sum(prob_list(1:c)))
%             alt_file_idx = orig_idx(c);
%             break;
%           end
%         end
%         alternate_state_config_file = XM.config.alternate_state_config_files{alt_file_idx};
%
%         %DisplayMessageToUser(['--- Using alternate state config file: ' alternate_state_config_file]);
%
%         %--- Reload all configuration files, so we can do live updates
%         CallFailSafe('LoadTaskStateConfigFile', alternate_state_config_file);
%
%         XM.insert_alternate_state = true;
%       end
%     end
%   end

if ~XM.insert_alternate_state
  % Increment rep counter
  if( isempty( XM.combos_to_be_tried))
    XM.rep_num = XM.rep_num + 1;
  end
  
  fprintf('\n======= [ Trial #%d, Rep #%d ] =======\n', XM.trial_num, XM.rep_num);
  
  %--- Reload all configuration files, so we can do live updates
  CallFailSafe('LoadTaskStateConfigFile',  GetTaskStateConfigFileName());
  
  target_configurations = XM.config.task_state_config.target_configurations;
  %--- Start a new rep if there are no targets left to be tried
  if( isempty( XM.combos_to_be_tried))
    % Reset targets
    num_combos = length(target_configurations.combos.tool);
    XM.combos_to_be_tried = 1 : num_combos;
    XM.num_times_tried_combo = zeros( 1, num_combos);
  end
  
  %--- select next target out of those that are still to be tried
  selection_mode = target_configurations.combos.selection_mode;
  if( ~isempty(findstr(lower(selection_mode), 'sequential')))
    XM.active_combo_index = XM.combos_to_be_tried(1);
  elseif( ~isempty(findstr(lower(selection_mode), 'random')))
    XM.active_combo_index = ...
      XM.combos_to_be_tried(random('Discrete Uniform',...
      length(XM.combos_to_be_tried)));
  else
    fprintf('\nWarning: Invalid target_configurations.combos.selection_mode "%s"\n', selection_mode);
    fprintf('defaulting to random\n');
    XM.active_combo_index = XM.combos_to_be_tried(random('Discrete Uniform',length(XM.combos_to_be_tried)));
  end
  
  %--- Report the number of tries left
  if( XM.config.max_num_tries_per_target > 0 )
    triesLeft = XM.config.max_num_tries_per_target -...
      XM.num_times_tried_combo(XM.active_combo_index);
    num_tries_left = num2str(triesLeft);
    DisplayMessageToUser([num_tries_left ' tries left for this combo']);
  else
    num_tries_left = 'INFINITE';
  end
  
else
  num_combos = length(target_configurations.combos.tool);
  combos_to_be_tried = 1 : num_combos;
  XM.active_combo_index = combos_to_be_tried(random('Discrete Uniform',length(combos_to_be_tried)));
end


fprintf('Using combo index: %d' , XM.active_combo_index);


% Tell SPM to flag the next sample as an alignment sample
% So that we can get an alignment pulse from the robot controller
% to get an unambiguous alignment between samples and timing pulses
SendSignal RESET_SAMPLE_ALIGNMENT;

if(isfield(XM, 'runtime'))
  XM.runtime.cancel_button_pressed = 0;
end

XM.penalty_time = 0;

%--- Send out informational message that says how this trial is configured
% (for anyone that cares)
SendTrialConfig( );
