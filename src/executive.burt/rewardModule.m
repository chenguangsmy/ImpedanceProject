function rewardModule( ConfigFile, mm_ip )
  % RewardModule( ConfigFile, mm_ip)
  %
  % ConfigFile is the file name of the main config file that should be
  % loaded from the config/ directory
  %
  % mm_ip is the network address of the MessageManager
  %
  % Ivana Stevens 8/21/2018

  NOTE_TEXT = 'Subject 12345'; % Will Be "Sonic" eventually
  NOTE_EPOC = 'Tick';

  MessageTypes = {...
          'JOYPAD_R1'...
          'JOYPAD_X' ...
          'PS3_BUTTON_PRESS' ...
          'PS3_BUTTON_RELEASE' ...
          'EXIT' ...
          'JUDGE_VERDICT'...
          'PING' ...
          'GIVE_REWARD' ...
          };

  %Dragonfly_BaseDir = getenv('DRAGONFLY');
  RTMA_BaseDir = getenv('RTMA');

  addpath([RTMA_BaseDir '/lang/matlab']);
  %App_SourceDir = getenv('BCI_MODULES');
  App_IncludeDir = getenv('ROBOTINC');

  MessageConfigFile = [App_IncludeDir '\RTMA_config.mat'];
  ModuleID = 'EXEC_MOD';

%   ConnectArgs = {ModuleID, '', MessageConfigFile};
%   if exist('mm_ip','var') && ~isempty(mm_ip)
%       ConnectArgs{end+1} = '-server_name pfem:7112';
%   end
% 
%   ConnectToMMM(ConnectArgs{:});
ConnectToMMM(0, '', [getenv('ROBOTINC') '\RTMA_config.mat'], '-server_name pfem:7112')
  Subscribe( MessageTypes{:})

  disp 'RewardModule running...'

  % connect to Workbench and TTank servers
  h = figure('Visible', 'off', 'HandleVisibility', 'off');
  TD = actxcontrol('TDevAcc.X', 'Parent', h);
  TD.ConnectServer('Local');

  sysmode = TD.GetSysMode;

  while(TD.GetSysMode==2 || TD.GetSysMode==3)
      %TD.SetTargetVal('Unit1_UD.ButtonPwr', 0);
      %fprintf('\nWaiting for message\n');
      M = ReadMessage( 'blocking');
      
      
      s = TD.GetTargetVal('Unit1_UD.BtnPress');
      coefs = TD.ReadTargetVEX('Unit1_UD.BtnPress', 0, 50, 'F32', 'F64');
      coefs2 = TD.ReadTargetVEX('Unit1_UD.Butn', 0, 50, 'F32', 'F64');
      
      
      if (sum(coefs2) > 0)
        disp "YES"
        return
      end

      switch(M.msg_type)
          case 'EXIT'
              break;
              
          case 'GIVE_REWARD'
              fprintf('Rewarding... %s\n', M.msg_type);
              %iter = M.data.num_clicks;
              duration = M.data.duration_ms;
              %for i = 1:iter
                  TD.SetTargetVal('Unit1_UD.Reward', 5);
                 % TD.SetTargetVal('Unit1_UD.ButtonPwr', duration);
                  pause(0.05);
                  TD.SetTargetVal('Unit1_UD.Reward',0);
                  %TD.SetTargetVal('Unit1_UD.ButtonPwr', 0);
                  pause(0.05);
             % end

      end

  end

  TD.CloseConnection
  DisconnectFromMMM

end


function [ out ] = readJson( fname )
% readJson:  Read in json config file
  fid = fopen(fname);
  raw = fread(fid,inf);
  str = char(raw');
  fclose(fid);
  out = jsondecode(str);

end  % function
