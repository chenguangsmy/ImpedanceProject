%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [outcome, next_state] = TaskStateEnded( id, rcv_event, task_state_config)

  global XM;
  global EVENT_MAP;
  global RTMA;

  next_state = 0;

  if (isempty(rcv_event))
      return;
  end

  EVENT_MAP.JV_TIMED_OUT      = task_state_config.timed_out_conseq;
  EVENT_MAP.JV_THRESHOLD      = 1;
  EVENT_MAP.JV_THRESHOLD_FAIL = 0;
  EVENT_MAP.JV_IDLE_TIMEOUT   = 0;
  if (strcmp(rcv_event.msg_type, 'JUDGE_VERDICT'))
      rcv_event.msg_type = sprintf('JV_%s', rcv_event.data.reason);
  end

  msg = RTMA.MDF.END_TASK_STATE;
  msg.id = int32(id);
  msg.outcome = int32(EVENT_MAP.(rcv_event.msg_type));
  text = rcv_event.msg_type;
  msg.reason = [int8(str2num(sprintf('%d ', text))) zeros(1, 64-length(text))];
  SendMessage( 'END_TASK_STATE', msg);

% if task state failed and denso was moving, halt it immediately
  if( XM.config.enable_denso && task_state_config.use_denso )
  if (EVENT_MAP.(rcv_event.msg_type) == 0)
    if ~strcmp(task_state_config.present_target, '-')
      HaltBurt();
    end
  end
end

  [task_state_config.reward, valid] = CalculateReward(task_state_config.reward);
  if ~valid, fprintf('WARNING: task_state_config.reward is invalid!\n'); end

  [task_state_config.consolation, valid] = CalculateReward(task_state_config.consolation);
  if ~valid, fprintf('WARNING: task_state_config.consolation is invalid!\n'); end

  switch(EVENT_MAP.(rcv_event.msg_type))
      case 0  % failed
          outcome = 0;
          if (XM.runtime.cancel_button_pressed == 1) || strcmpi(rcv_event.msg_type, 'JV_IDLE_TIMEOUT')
              FailedToStart_state();
          else
              XM.penalty_time = task_state_config.time_penalty;

              % Implement a per task state consolation reward
              % GiveReward( task_state_config.consolation);

              if( XM.trial_started)
                  Failed_state();
              else
                  FailedToStart_state();
              end

              if isfield(task_state_config, 'play_sound') && ...
                 (strcmpi(task_state_config.play_sound, 'f') || strcmpi(task_state_config.play_sound, 'sf') )
                  msg = RTMA.MDF.PLAY_SOUND;
                  msg.id = int32(1);
                  SendMessage( 'PLAY_SOUND',msg);
              end
          end
          next_state = find(XM.config.task_state_config.task_end_state == 1, 1, 'first');

      case 1  % success/completion
          outcome = 1;

          % A trial is considered to begin for real when we succeed in a task state
          % that has been marked "trial_begins"
          if( task_state_config.trial_begins)
              if( ~XM.trial_started)
                  XM.trial_started = true;
                  fprintf('\n Trial started\n');
              end
          end

          % A trial is considered complete after we complete the task state that
          % has been configured as "trial_complete"
          if( task_state_config.trial_complete)
              fprintf('\n Trial complete\n');
              Success_state();
          end

          % Implement a per task state reward
          %if(int32(XM.active_combo_index)==1 || int32(XM.active_combo_index)==2)
          %  task_state_config.reward = round(task_state_config.reward*8)
          %end

          fprintf(num2str(task_state_config.reward));
        % The reward can take format e#; N#,#; or # to support exponential, normal or constant reward.
        % If the code is using GiveDirectReward, the number represents the number of clicks.
        % Need min 5 clicks to run through 60ml/120 trials
        % If the code uses GiveReward, the number represents the pause duration in ds, 
        % i.e. 50 -> 0.5s pause between task success and reward delivery. 
          GiveDirectReward(task_state_config.reward);

          % Play reward sound
          if isfield(task_state_config, 'play_sound') && ...
             (strcmpi(task_state_config.play_sound, 's') || strcmpi(task_state_config.play_sound, 'sf') )
              msg = RTMA.MDF.PLAY_SOUND;
              msg.id = int32(2);
              SendMessage( 'PLAY_SOUND',msg);
          end
  end
