
function SimpleJudgeDisplay(config_file, mm_ip)

    % dbstop if error;

    global RTMA;
    global done;
    global pause_plotting;

    RTMAPath = getenv('RTMA');
    SourcePath = getenv('ROBOTSRC');
	CommonPath = getenv('ROBOT_COMMON');
    IncludePath = getenv('ROBOTINC');

    addpath([RTMAPath '/lang/matlab']);
	addpath([CommonPath '/Matlab']);

    RTMAConfigFile = [IncludePath '/RTMA_config.mat'];
    ConnectArgs = {0, '', RTMAConfigFile};
    if exist('mm_ip','var') && ~isempty(mm_ip)
        ConnectArgs{end+1} = ['-server_name ' mm_ip];
    end
    ConnectToMMM(ConnectArgs{:})

    task_state_config_received = false;

    Subscribe TASK_STATE_CONFIG
    Subscribe EXIT
    Subscribe PING

    % Needed to fix dual monitor setup:
    set(0,'DefaultFigureRenderer','OpenGL')
    set(0,'DefaultFigureRendererMode', 'manual')

    % load configuration & init display
    c = LoadTextData( config_file);
    config = c.config;
    State = InitJudgeDisplay(config);
    figure;

    hExitButton = uicontrol('Style', 'pushbutton', 'String', 'Exit', 'Position', [5 5 60 20]);
    set(hExitButton, 'callback', {'ExitApp', hExitButton});

    disp('SimpleJudgeDisplay running...');
    fprintf('config: %s\n\n', config_file);

    pause_plotting = 0;
    done = 0;
    while(~done)
        M = ReadMessage( 0);
        if(isempty(M))
            if ~pause_plotting
                PlotLiveData( State, config);
            end
            pause( 0.01);
        else
			switch( M.msg_type)

                case 'TASK_STATE_CONFIG'
					State.trial_config = M.data;
                    c = LoadTextData( config_file);
                    config = c.config;
                    if ~task_state_config_received
                        Subscribe ROBOT_CONTROL_SPACE_ACTUAL_STATE
                        task_state_config_received = true;

                        hPause = uicontrol('Style', 'pushbutton', 'String', 'Pause',...
                                           'Position', [75 5 60 20]);
                        set(hPause, 'callback', {'PausePlotting', hPause});
                    end

				case 'ROBOT_CONTROL_SPACE_ACTUAL_STATE'
                    CommandSpaceFbk = M.data;
                    State.fdbk.actual_pos = CommandSpaceFbk.pos;
                    State = UpdateJudgingStatus( State, config);

                case 'PING'
                    RespondToPing(M, 'SimpleJudgeDisplay');

                case 'EXIT'
                    if (M.dest_mod_id == GetModuleID()) || (M.dest_mod_id == 0)
                        SendSignal EXIT_ACK
                        break;
                    end

			end
        end
    end
    DisconnectFromMMM
    close all
    exit


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ExitApp(hObj, eventdata, handle)
    global done;
    done = 1;


function PausePlotting(hObj, eventdata, handle)

    global pause_plotting;

    button_text = get(handle, 'String');

    if strcmp(button_text, 'Pause')
        set(handle, 'String', 'Continue')
        pause_plotting = 1;
    else
        set(handle, 'String', 'Pause')
        pause_plotting = 0;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function PlotLiveData(State, config)

    dims = config.active_finger_dims;
    nDims = length(dims);
    xN = length(State.LiveData.TaskStateNo);
    bg = fields(config.marked_task_states);

    for d = 1 : nDims
        subaxis(nDims,1,d, 'Spacing', 0.01, 'Padding', 0.02, 'Margin', 0.01);

        plot(State.LiveData.ActualPos{d}, 'k');

        xlim([1 xN]);
        finger_idx = config.active_finger_dims(d);

        min_scale = State.LiveData.min_scale{finger_idx};
        if isfield(config, 'min_scale')
            min_scale = config.min_scale(finger_idx);
        end
        max_scale = State.LiveData.max_scale{finger_idx};
        if isfield(config, 'max_scale')
            max_scale = config.max_scale(finger_idx);
        end
        ylim([min_scale max_scale]);
        yLimG = get( gca, 'YLim'); % [ymin ymax]

        hold on;
        % draw dummy threshold so that its color shows up in the legend
        line(0, 0, 'Color', config.threshold_color, 'visible', 'off');

        for b = 1 : length(bg)
            b_id = config.marked_task_states.(bg{b}).id;
            b_color = config.marked_task_states.(bg{b}).color;
            mask = State.LiveData.TaskStateNo==b_id;
            if (sum(mask) > 0)
                PlotBackgroundMask(1:xN, mask, [], b_color);
            else
                % always draw patch for all colors so that they will always show up in the legend
                patch([0 1 1 0]', [0 0 1 1]', b_color, 'visible', 'off');
            end
        end

        % finger_threshold_judging_method: 1=distance, 2=absolute
        % finger threshold_judging_polarity: 1 = <, 2 = >
        methods = ~isnan(State.LiveData.JudgingMethod{d});
        if (sum(methods) > 0)
            methods = unique(State.LiveData.JudgingMethod{d}(methods));
            for m = 1 : length(methods)
                method = methods(m);
                met_mask = State.LiveData.JudgingMethod{d}==method;
                polaritys = unique(State.LiveData.JudgingPolarity{d}(met_mask));

                for p = 1 : length(polaritys)
                    polarity = polaritys(p);
                    pol_mask = (State.LiveData.JudgingPolarity{d} == polarity);
                    mask = met_mask & pol_mask;

                    yLimUs = unique(State.LiveData.ThreshUpper{d}(mask));

                    for b = 1 : length(yLimUs)
                        yLimU = yLimUs(b);
                        submask = (State.LiveData.ThreshUpper{d} == yLimU) & mask;

                        if (method == 1) %dist
                            yLimLs = unique(State.LiveData.ThreshLower{d}(submask));

                            for k = 1 : length(yLimLs)
                                yLimL = yLimLs(k);
                                submask2 = (State.LiveData.ThreshLower{d} == yLimL) & submask;

                                if (polarity == 1) % <
                                    PlotBackgroundMask(1:xN, submask2, [yLimL yLimU], config.threshold_color);
                                else
                                    PlotBackgroundMask(1:xN, submask2, [yLimG(1) yLimL], config.threshold_color);
                                    PlotBackgroundMask(1:xN, submask2, [yLimU yLimG(2)], config.threshold_color);
                                end
                            end
                        else            % abs
                            if (polarity == 1) % <
                                PlotBackgroundMask(1:xN, submask, [yLimG(1) yLimU], config.threshold_color);
                            else
                                PlotBackgroundMask(1:xN, submask, [yLimU yLimG(2)], config.threshold_color);
                            end
                        end
                    end
                end
            end
        end
        hold off;
        set(gca,'XTick',[]);
        title(sprintf('finger dim %d', dims(d)));
    end
    legend([{'Position', 'Threshold'} bg'], 'Location', 'SouthOutside', 'Orientation', 'horizontal');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitJudgeDisplay(config)
    State = struct();
	State.trial_config = [];
	State.fdbk = [];

    N = config.number_of_data_points;
    nDims = 4;
    for d = 1 : nDims
        State.LiveData.ActualPos{d} = zeros(1, N);
        State.LiveData.ThreshUpper{d} = nan(1, N);
        State.LiveData.ThreshLower{d} = nan(1, N);
        State.LiveData.JudgingMethod{d} = nan(1, N);
        State.LiveData.JudgingPolarity{d} = nan(1, N);
        State.LiveData.max_scale{d} = eps;
        State.LiveData.min_scale{d} = -eps;
    end
    State.LiveData.TaskStateNo = zeros(1, N);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = UpdateJudgingStatus( State, config)

    finger_dofs_to_judge = find(~isnan(State.trial_config.finger_threshold)>0);

    dims = config.active_finger_dims;
    nDims = length(dims);

    for d = 1 : nDims

        finger_idx = dims(d);
        finger_actual_pos = State.fdbk.actual_pos(8+finger_idx);

        % default values (ie, if there is no judging)
        threshU = nan;
        threshL = nan;
        method = nan;
        polarity = nan;

        if ~isempty(find(finger_idx == finger_dofs_to_judge))

            thresh = State.trial_config.finger_threshold(finger_idx);
            method = State.trial_config.finger_threshold_judging_method(finger_idx);
            polarity = State.trial_config.finger_threshold_judging_polarity(finger_idx);

            % finger_threshold_judging_method: 1=distance (default), 2=absolute
            if ( method == 1)  % dist
                target = State.trial_config.target(8+finger_idx);
                threshU = target + thresh;
                threshL = target - thresh;
            else  % absolute
                threshU = thresh;
                threshL = nan;
            end
        end

        % insert new data to plotting arrays
        State.LiveData.ActualPos{d}     = AddDataToWindowedArray(State.LiveData.ActualPos{d}, finger_actual_pos);
        State.LiveData.ThreshUpper{d}   = AddDataToWindowedArray(State.LiveData.ThreshUpper{d}, threshU);
        State.LiveData.ThreshLower{d}   = AddDataToWindowedArray(State.LiveData.ThreshLower{d}, threshL);
        State.LiveData.JudgingMethod{d} = AddDataToWindowedArray(State.LiveData.JudgingMethod{d}, method);
        State.LiveData.JudgingPolarity{d} = AddDataToWindowedArray(State.LiveData.JudgingPolarity{d}, polarity);

        min_data = min(State.LiveData.ActualPos{d});
        if ( min_data < State.LiveData.min_scale{finger_idx})
            State.LiveData.min_scale{finger_idx} = min_data;
        end

        max_data = max(State.LiveData.ActualPos{d});
        if ( max_data > State.LiveData.max_scale{finger_idx})
            State.LiveData.max_scale{finger_idx} = max_data;
        end
    end

    State.LiveData.TaskStateNo(1) = [];
    State.LiveData.TaskStateNo(end+1) = State.trial_config.id;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Array = AddDataToWindowedArray(Array, data)
    Array(end+1) = data;
    Array(1) = [];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = less_than(target, threshold)
    res = target < threshold;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function res = greater_than(target, threshold)
    res = target > threshold;

