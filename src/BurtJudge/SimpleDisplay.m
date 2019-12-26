
function SimpleJudgeDisplay(config_file, mm_ip)
    
    % dbstop if error;

    global RTMA;

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

    Subscribe ROBOT_CONTROL_SPACE_ACTUAL_STATE

    % load configuration & init display
    %c = LoadTextData( config_file);
    %config = c.config;
    config.number_of_data_points = 500;
    config.active_dims = [9 11];
    config.max_scale = .6;
    config.min_scale = -.2;
    config.threshold_color = [.95 .95 .95];
    
    State = InitJudgeDisplay(config);
    figure;

    disp('SimpleDisplay running...');
   
    while(1)
        M = ReadMessage( 0);
        if(isempty(M))
            PlotLiveData( State, config);
            pause( 0.01);
        else
			switch( M.msg_type)

				case 'ROBOT_CONTROL_SPACE_ACTUAL_STATE'
                    CommandSpaceFbk = M.data;
                    State.fdbk.actual_pos = CommandSpaceFbk.pos;
                    %State.fdbk.actual_vel = CommandSpaceFbk.vel;
                    State = UpdatePlotData( State, config);
			end
        end
    end
    DisconnectFromMMM

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitJudgeDisplay(config)

    State = struct();
    
    N = config.number_of_data_points;
    nDims = 4;
    for d = 1 : nDims
        State.LiveData.ActualPos{d} = zeros(1, N);
    end
       
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function PlotLiveData(State, config)
    
    dims = config.active_dims;
    nDims = length(dims);
    xN = config.number_of_data_points;

    for d = 1 : nDims
        subaxis(nDims,1,d, 'Spacing', 0.01, 'Padding', 0.02, 'Margin', 0.01);

        plot(State.LiveData.ActualPos{d}, 'k');

        xlim([1 xN]); 
        dim_idx = config.active_dims(d);
        %ylim([config.min_scale(dim_idx) config.max_scale(dim_idx)]);
        ylim([config.min_scale config.max_scale]);
        yLimG = get( gca, 'YLim'); 
        
        set(gca,'XTick',[]);
        title(sprintf('Dim %d', dims(d)));
    end  
    legend({'Position'}, 'Location', 'SouthOutside', 'Orientation', 'horizontal');

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = UpdatePlotData( State, config)

    dims = config.active_dims;
    nDims = length(dims);
    
    for d = 1 : nDims
        
        dim_idx = dims(d);
        actual_pos = State.fdbk.actual_pos(dim_idx);

        % insert new data to plotting arrays
        State.LiveData.ActualPos{d} = AddDataToWindowedArray(State.LiveData.ActualPos{d}, actual_pos);
    end

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Array = AddDataToWindowedArray(Array, data)
    Array(end+1) = data;
    Array(1) = [];
    

