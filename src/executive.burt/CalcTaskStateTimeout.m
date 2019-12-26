function timeout = CalcTaskStateTimeout( task_state_config)

timeout = task_state_config.timeout;
TOMax = timeout * (1 + (task_state_config.timeout_range_percent / 100));

% Pick timeout value randomly between min and max
if (timeout ~= TOMax)
  timeout = random( 'Uniform', timeout, TOMax);
end