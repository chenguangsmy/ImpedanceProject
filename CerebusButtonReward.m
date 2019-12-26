% This module works with Blackrock Cerebus Neural Signal Processor
%   to receive button signal from the chair and send reward signal
%   to the reward box.
%
% Hardware configuration
%   aout1: 5 V input signal to button
%   ainp1: button output signal (low pass 500 Hz, sampling rate 1k Hz)
%   aout4: signal to reward box (the "level" port in the back)
%
% Hongwei Mao 7/18/2019

function CerebusButtonReward(config_file, mm_ip)

close all; clear; clc;

RTMAPath    = getenv('RTMA');
IncludePath = getenv('ROBOTINC');
ConfigPath  = getenv('ROBOT_CONFIG');
SourcePath  = getenv('ROBOTSRC');
CerebusPath = getenv('CBDIR');

addpath([RTMAPath '\lang\matlab']);
addpath([SourcePath '\Common\Matlab']);
addpath(CerebusPath);

if (nargin < 1)
    config_file = [ConfigPath '\default\CerebusButtonReward.conf'];
end
Config = LoadValidateConfigFile(config_file, {});
Config = Config.config;


%% Connect to and set up Cerebus
DisconnectFromCerebus(Config.nsp_instance);
% Digital output: a) high TTL to button, b) TTL signal to reward box
% Digital input:  button signal (port function: 16-bit falling edge)
ConnectToCerebus(Config);

%% Test button 
prompt = 'Test button? y/n [y]: ';
button_test_time = 30;  % seconds
while(1)
    in_str = input(prompt, 's');
    if strcmpi(in_str, 'n')
        fprintf('Start CerebusButtonReward.\n');
        break;
    else
        tic;
        fprintf(['You have ' num2str(button_test_time) ' seconds to test the button  ... ']);
    end
    
    while (toc < button_test_time)
        [event_data] = cbmex('trialdata', 1, 'instance', Config.nsp_instance);
        digit_in_event = event_data{Config.DIGIT_IN_CH_INDEX, Config.DATA_COLUMN_INDEX};
        if ~isempty(digit_in_event)
            CerebusReward(Config);
        end
        pause(0.02);
    end
    fprintf('Done.\n');
    prompt = 'Test button again? y/n [y]: ';
end

%% Connect to MessageManager module
if (nargin > 1)
    Config.mm_ip = mm_ip;
end
RTMAConfigFile = [IncludePath '\RTMA_config.mat'];
load(RTMAConfigFile); % load RTMA message definitions
DisconnectFromMMM
ConnectToMMM(0, '', RTMAConfigFile, ['-server_name ' Config.mm_ip]);

%% Subscribe to RTMA messages
MessageTypes = {...
    'SAMPLE_GENERATED' ...
    'TRIAL_CONFIG' ...
    'TASK_STATE_CONFIG' ...
    'GIVE_REWARD' ...
    'EXIT' ...
    };
Subscribe( MessageTypes{:})

%% The main loop: process RTMA messages
detectButtonPress = false;
buttonPressed     = false;

while(1)
    M = ReadMessage(1);
    if (~isempty(M))
        switch(M.msg_type)
            case 'SAMPLE_GENERATED'
                if detectButtonPress
                    % button signal comes in through digital input port
                    [event_data] = cbmex('trialdata', 1, 'instance', Config.nsp_instance);
                    if isempty(event_data{Config.DIGIT_IN_CH_INDEX, Config.DATA_COLUMN_INDEX})
                        buttonPressed = false;
                        continue;
                    else
                        buttonPressed = true;
                        fprintf('Button pressed\n');
                    end

                    if buttonPressed
                        % only the first button press event counts
                        detectButtonPress = false;
                        
                        movehome = RTMA.MDF.MOVE_HOME;
                        movehome.shouldMove = int32(buttonPressed);
                        SendMessage('MOVE_HOME', movehome);
                    end
                end
                
            case 'TRIAL_CONFIG'
                fprintf('---------- Trial %d ----------\n', M.data.trial_no);
                % clear NSP buffer at the start of a new trial
                % so any button presses from the previous trial will be discarded
                cbmex('trialdata', 1, 'instance', Config.nsp_instance);
                
            case 'TASK_STATE_CONFIG'
                % only allow moving in the 1st task state
                % not a good way of coding but would work for now
                if (M.data.id == 1)
                    detectButtonPress = true;
                else
                    detectButtonPress = false;
                end
                
            case 'GIVE_REWARD'
                if (M.data.duration_ms > 0)
                    duration = double(M.data.duration_ms) / 1000;  % ms -> s
                    CerebusReward(Config, duration);
                    fprintf('Give Reward: t = %.3f s\n', duration);
                elseif (M.data.num_clicks > 0)
                    for iclick = 1:ceil(M.data.num_clicks)
                        %default duration = 0.01s
                        CerebusReward(Config, Config.reward_default_duration);
                        pause(0.1);
                    end
                    fprintf('Give Reward by clicks: n = %.3f \n', ceil(M.data.num_clicks));
                end
        end
    end
end


function ConnectToCerebus(Config)

% open an interface to Cerebus
try
    cbmex('open', Config.nsp_interface, 'central-addr', Config.nsp_ip, ...
                  'instance', Config.nsp_instance);
catch ME
    cbmex('close', 'instance', Config.nsp_instance);
    error(sprintf('Failed to connect to NSP @ %s.\n', Config.nsp_ip));
end

% set dout for reward to low
cbmex('digitalout', Config.REWARD_CH_NO, 0, 'instance', Config.nsp_instance); % set low

% set dout to power the button (set low, so when button is pressed, its output will be low)
cbmex('digitalout', Config.BUTTON_PWR_CH_NO, 0, 'instance', Config.nsp_instance); % set low

% activate all channels
cbmex('mask', 0, 1, 'instance', Config.nsp_instance);  % deactivate all channels

% flush the data cache and start buffering data
cbmex('trialconfig', 1, 'instance', Config.nsp_instance, ...
      'double', 'absolute', 'nocontinuous', 'event', Config.NUM_BUFFER_EVENT);
% cbmex('trialconfig', 1, 'instance', Config.nsp_instance, ...
%       'double', 'absolute', 'continuous', Config.ainp_num_buffer_sample, 'noevent');


function DisconnectFromCerebus(nsp_instance)
cbmex('close', 'instance', nsp_instance);


function CerebusReward(Config, duration)
if nargin < 2
    duration = Config.reward_default_duration;
end
%FIXME: Shuqi 11-29-2019, this doesn't seem right, the duration here represents
%how long the program waits to deliver reward instead of the duration of
%the reward given.
cbmex('digitalout', Config.REWARD_CH_NO, 1, 'instance', Config.nsp_instance); % set high
pause(duration);    % seconds
cbmex('digitalout', Config.REWARD_CH_NO, 0, 'instance', Config.nsp_instance); % set low
