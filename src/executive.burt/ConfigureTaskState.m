%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Defines how you read in task state data. 
% Requires Move complete message from robot
function ConfigureTaskState(task_state_config)

global XM;
global EVENT_MAP;

%
% EVENT_MAP.<event name> = <outcome> (0=failure, 1=success)
%
EVENT_MAP = struct();

% Placeholder so we can receive the message, actual outcomes are
% setup in taskStateEnded()
EVENT_MAP.JUDGE_VERDICT     = [];

events = fieldnames(task_state_config.event_mappings);
for i = 1 : length(events)
  event = events{i};
  
  if (strcmp(event, 'DENSO_MOVE_COMPLETE'))
    continue;
  end
  
  if( strcmpi(task_state_config.event_mappings.(event), 's'))
    EVENT_MAP.(event) = 1;
  elseif( strcmpi(task_state_config.event_mappings.(event), 'f'))
    EVENT_MAP.(event) = 0;
  end
end

switch( upper(task_state_config.manual_proceed))
  case '-'  % means not configured for manual proceed, Do not add any mapping
  case 'A'  % means manual proceed allowed, so add a mapping for it
    EVENT_MAP.PROCEED_TO_NextState = 1;
  case 'R'  % means manual proceed REQUIRED, so replace all other mappings
    EVENT_MAP = struct();
    EVENT_MAP.PROCEED_TO_NextState = 1;
  otherwise
    error( 'Invalid value for task_state_config.manual_proceed');
end

switch( upper(task_state_config.manual_cancel))
  case '-'  % means not configured for manual cancel, so do not add any mapping
  case 'A'  % means manual cancel allowed, so add a mapping for it
    EVENT_MAP.PROCEED_TO_Failure = 0;
  otherwise
    error( 'Invalid value for task_state_config.manual_cancel');
end

% in case 'r' was specified, we need to handle 'PAUSE_EXPERIMENT' as a special case
for i = 1 : length(events)
  event = events{i};
  if strcmp(event, 'PAUSE_EXPERIMENT')
    if ( strcmpi(task_state_config.event_mappings.(event), 's'))
      EVENT_MAP.(event) = 1;
    elseif( strcmpi(task_state_config.event_mappings.(event), 'f'))
      EVENT_MAP.(event) = 0;
    end
  end
end


if ( ~isempty(fieldnames(EVENT_MAP)))
  EVENT_MAP.XM_ABORT_SESSION = 0;
end
