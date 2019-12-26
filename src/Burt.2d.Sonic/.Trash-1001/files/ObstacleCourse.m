function ObstacleCourse(conf_file,mm_ip)
% This takes in a cell array of strings for the config_filenames
% Each cell string would be the filename for an obstacle config file
% Currently, there are two types of obstacles that can be created,
% a world-centered box and a spere offset from the DENSO target.
% Collision is detected as the fingertip of the MPL being inside a defined obstacle region
% All obstacle config files must have the variable ObsType which defines
% the type of obstacle, either:
% WORLD_Box or DENSO_Sphere
% The WORLD_Box file must have the variables Top, Btm, Lft, Rgt, Frt, and Bck which define
% the limits of the box obstacle in the world frame
% The DENSO_Sphere file must have the variables AvoidRad, numSmCrcpts, and TargCtrOFFSET
% AvoidRad defines the radius of the sphere obstacle
% numSmCrcpts defines the number of points with which to populate the target cloud during collision
% TargCtrOFFSET defines the x,y,z offset of the CENTER of the sphere from the output DENSO target location
% this will be rotated by the DENSO orientation, thus it is the offset in the DENSO target frame
% The state_filename will be only one string defining the filename of the state config file
% This config file must have the variables MPLEEtoFing, domain_map, ortho_impedance, and tag
% MPLEEtoFing defines the x,y,z offset from the output MPL end-effector to the fingertip
% this will be rotated by the MPL orientation, thus it is the offset in the MPL end-effector frame
% for the time being, we will just go on the assumption that the finger is always fully extended
% domain_map, ortho_impedance, and tag are the same things it has been as in the other virtual fixturing
% However, this version is assuming the same type of fixturing for each obstacle, and why not
% Generally, for all used domains you'd likely be using ortho_impedance of 1, again why not
% altough, maybe eventually we could implement soft-shells for each of the obstacles...

RTMAPath = getenv('RTMA');
IncludePath = getenv('ROBOTINC');
CommonPath = getenv('ROBOT_COMMON');

addpath([RTMAPath '/lang/matlab']);
addpath([CommonPath '/Matlab']);

%if(~exist(state_filename,'var'))
%    error('State files must be specified as an input argument');
%end
if(~exist(conf_file,'file'))
    error(['Cannot find state file: ' conf_file]);
end
State = LoadTextData(conf_file);
State = InitializeState(State);

%

config = cell(size(State.config_filenames));
[ConfDir Blank Blitz] = fileparts(conf_file);
for i = 1:length(State.config_filenames)
    CurCfgFN = fullfile(ConfDir, State.config_filenames{i});
    if( ~exist(CurCfgFN, 'file'))
        error(['Cannot find config file: ' CurCfgFN]);
    end
    config{i} = LoadTextData(CurCfgFN);
%     config{i} = InitializeVariables(config{i});
end

ConnectArgs = {'OBSTACLE_COURSE', '', [IncludePath '/RTMA_config.mat']};
if exist('mm_ip','var') && ~isempty(mm_ip)
    ConnectArgs{end+1} = ['-server_name ' mm_ip];
end
ConnectToMMM(ConnectArgs{:})

Subscribe EXIT
Subscribe PING

% Subscribe ROBOT_CONTROL_CONFIG;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SUBSCRIBE TO DENSO ROBOT STATE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Subscribe PROBOT_FEEDBACK;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SUBSCRIBE TO MPL ARM STATE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Subscribe ROBOT_CONTROL_SPACE_ACTUAL_STATE;
Subscribe COMPOSITE_MOVEMENT_COMMAND;

while(1)
    M = ReadMessage(0);
    if(isempty(M))
        fprintf('.');
        %drawnow;
        pause(0.01);
    else
        State = ProcessMessage(M, config, State);
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = ProcessMessage(M, config, State)

switch(M.msg_type)
%     case 'ROBOT_CONTROL_CONFIG'
%         rc_config = M.data;
%         config.ortho_impedance = rc_config.orthVelImpedance';        

    case 'PING'
        RespondToPing(M, 'ObstacleCourse');
        
    case 'EXIT'
        if (M.dest_mod_id == GetModuleID()) || (M.dest_mod_id == 0)
            SendSignal EXIT_ACK
            DisconnectFromMMM
            exit
        end    

    case 'PROBOT_FEEDBACK'
        State.DensoPt = ProcDensoPt(M.data.tool_pos(1:3),M.data.tool_pos(4:6));
        State.HasDenso = 1;
        fprintf('HHII\n');
    case 'ROBOT_CONTROL_SPACE_ACTUAL_STATE'
        State.MPLpt = MPLtransEE(M.data.pos(1:3),reshape(M.data.CoriMatrix,3,3)',State);
        State.HasMPL = 1;
        %set(State.MPLHandle,'XData',[M.data.pos(1) ...
        %                    State.MPLpt(1,4)]);
        %set(State.MPLHandle,'YData',[M.data.pos(2) ...
        %                    State.MPLpt(2,4)]);
        %set(State.MPLHandle,'ZData',[M.data.pos(3) ...
        %                    State.MPLpt(3,4)]);
    case {'COMPOSITE_MOVEMENT_COMMAND'}
        extrinsic_cmd = M.data.vel';

        if  (~State.HasMPL)% || (~State.HasDenso)
            SendCommand(extrinsic_cmd,M.data,State.tag);
            fprintf('No Data yet\n');
        else
            State = CheckCollision(config,State);
            if State.Collision
                fprintf(['Cmd_Vel: x: ' num2str(extrinsic_cmd(1)) ...
                         ' y: ' num2str(extrinsic_cmd(2)) ' z: ' ...
                         num2str(extrinsic_cmd(3)) '\n']);
                FingPt_cmd = zeros(size(extrinsic_cmd));
                FingPt_cmd(logical(State.domain_map)) = TranslCmdVel(extrinsic_cmd(logical(State.domain_map)),State);
                FingPtout_cmd = zeros(size(extrinsic_cmd));
                output_cmd = extrinsic_cmd;
                unique_domains = unique(State.domain_map(State.domain_map~=0));
                for i = 1 : length(unique_domains)
                    this_domain = unique_domains(i);
                    domain_mask = (State.domain_map == this_domain);
                    D = State.target_cloud(domain_mask,:);
                    u = FingPt_cmd(domain_mask);
                    domain_admittance = 1 - State.ortho_impedance(domain_mask);
                    Ct = diag(domain_admittance)
                    v = apply_ortho_impedance(D, u, Ct);

                    FingPtout_cmd(domain_mask) = v;
                end
                output_cmd(logical(State.domain_map)) = ...
                    FingtoEEVel(FingPtout_cmd(logical(State ...
                                                      .domain_map)),State);
                fprintf(['OUT_Vel: x: ' num2str(output_cmd(1)) ...
                         ' y: ' num2str(output_cmd(2)) ' z: ' ...
                         num2str(output_cmd(3)) '\n']);
                SendCommand(output_cmd, M.data, State.tag);
                if norm(extrinsic_cmd(1:3)) > 0 && State.PlotCounter ...
                        == 1
                    tt = extrinsic_cmd(1:3);
                    tt = tt/norm(tt);
                    rr = output_cmd(1:3);
                    rr = rr/norm(rr);
                    inv1 = [State.MPLpt(1,4), State.MPLpt(1,4)+ ...
                            tt(1)];
                    inv2 = [State.MPLpt(2,4), State.MPLpt(2,4)+ ...
                            tt(2)];
                    inv3 = [State.MPLpt(3,4), State.MPLpt(3,4)+ ...
                            tt(3)];
                    outv1 = [State.MPLpt(1,4), State.MPLpt(1,4)+ ...
                             rr(1)];
                    outv2 = [State.MPLpt(2,4), State.MPLpt(2,4)+ ...
                             rr(2)];
                    outv3 = [State.MPLpt(3,4), State.MPLpt(3,4)+ ...
                             rr(3)];
                    % plot3(inv1,inv2,inv3,'g');
                    %plot3(outv1,outv2,outv3,'r');
                    %hold off;
                end

            else
                SendCommand(extrinsic_cmd, M.data, State.tag);
            end
        end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function config = InitializeVariables(config)
% %%%% System expects domain map to be x',y',z',R'_x,R'_y,R'_z %%%%%
% config.domain_map = config.domain_map(:); % Make it a column vector
% config.ortho_impedance = zeros(size(config.domain_map));
% config.target_cloud = zeros(size(config.domain_map));
% config.HasMPL = 0;
% config.HasDenso = 0;
% config.MPLpt = zeros(4);
% config.AvoidCtr = zeros(4);
% config.Collision = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = InitializeState(State)
State.domain_map = State.domain_map(:);
State.HasMPL = 0;
State.HasDenso = 0;
State.target_cloud = zeros(size(State.domain_map));
State.DensoPt = zeros(4);
State.MPLpt = zeros(4);
State.Collision = 0;
State.PlotCounter = 0;
%State.Handle = figure;
%hold on;
%State.DensoHandle = plot3([0 0],[0 0],[0 0],'go-');
%State.MPLHandle = plot3([0 0],[0 0],[0 0],'r');
%State.MPL2DensoH = plot3([0 0],[0 0],[0 0],'b');
%axis equal
%hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function State = CheckCollision(config,State)
x = State.MPLpt(1,4); y = State.MPLpt(2,4); z = State.MPLpt(3,4);
fprintf(['x: ' num2str(x) ', y: ' num2str(y) ', z: ' num2str(z) '\n']);
for i = 1:length(config)
    cfg = config{i};
    switch(cfg.ObsType)
      case 'DENSO_Sphere'
            AvoidCtr = AvoidPt(State,cfg);
            Diff = State.MPLpt(1:3,4)-AvoidCtr(1:3,4);
            Dist = norm(Diff);
            fprintf(['Sphere Ctr Dist: ' num2str(Dist) '\n']);
            if Dist <= cfg.AvoidRad
                %if isempty(State.Handle)
                %    State.Handle = figure;
                %end
                State.Collision = 1;
                SmCrcRad = sqrt(cfg.AvoidRad^2-(cfg.AvoidRad-Dist)^2);
                SmCrcCtr = (Diff./Dist).*(cfg.AvoidRad-Dist)+ ...
                    AvoidCtr(1:3,4);
                SmCrcBs = null(Diff');
                Dpts = zeros(3,cfg.numSmCrcpts+1);
                Ds = zeros(length(State.domain_map),cfg.numSmCrcpts+1);
                Thetas = linspace(0,(2*pi()-((2*pi())/cfg.numSmCrcpts)),cfg.numSmCrcpts);
                for j = 1:cfg.numSmCrcpts
                    Theta = Thetas(j);
                    cs = cos(Theta); sn = sin(Theta);
                    Dpts(:,j) = SmCrcCtr+SmCrcRad*cs*SmCrcBs(:,1)+SmCrcRad*sn*SmCrcBs(:,2);
                    Ds(1:3,j) = (Dpts(:,j)-AvoidCtr(1:3,4))./norm(Dpts(:,j)-AvoidCtr(1:3,4));
                end
                Dpts(:,end) = SmCrcCtr;
                Ds(1:3,end) = (Dpts(:,end)-AvoidCtr(1:3,4))./ ...
                    norm(Dpts(:,end)-AvoidCtr(1:3,4));
                if State.PlotCounter >= 10
                    State.PlotCounter = 0;
                    %  SpherePlot(AvoidCtr(1:3,4), State.MPLpt(1:3,4), Ds(1:3,:));
                end
                State.PlotCounter = State.PlotCounter + 1;
                State.target_cloud = Ds;

                break
            else
                State.Collision = 0;
            end
        case 'WORLD_Box'
            %%%%% LABELLED AS IN MONKEY VANTAGE POINT - world coord frames %%%%
            Top = cfg.Top; Btm = cfg.Btm; %%% world z-coord * - usually +/-inf %%%
            Lft = cfg.Lft; Rgt = cfg.Rgt; %%% world y-coord %%%
            Frt = cfg.Frt; Bck = cfg.Bck; %%% world x-coord * - note -x in application %%%

            if (x<Frt) && (x>Bck) && (y<Rgt) && (y>Lft) && (z<Top) &&(z>Btm)
                State.Collision = 1;
                x_Frt = Frt-x; x_Bck = x-Bck;
                [x_min,x_BF] = min([x_Bck,x_Frt]);
                y_Lft = y-Lft; y_Rgt = Rgt-y;
                [y_min,y_LR] = min([y_Lft,y_Rgt]);
                z_Top = Top-z; z_Btm = z-Btm;
                [z_min,z_BT] = min([z_Btm,z_Top]);
                [~,Far_xyz] = max([x_min,y_min,z_min]);
                Btm_z_BT = z_BT==1; Top_z_BT = z_BT==2;
                Lft_y_LR = y_LR==1; Rgt_y_LR = y_LR==2;
                Bck_x_BF = x_BF==1; Frt_x_BF = x_BF==2;
                switch(Far_xyz)
                    case 1 %%% Y & Z are the closest
                        [~,Cls_YZ] = min([y_min,z_min]);
                        Y_Cls_YZ = Cls_YZ==1; Z_Cls_YZ = Cls_YZ==2;
                        Norm = [0,z_min*((y_LR-1.5)*2),y_min*((z_BT-1.5)*2)];
                        z_Port = Z_Cls_YZ*(Btm_z_BT*Btm+Top_z_BT*Top);
                        z_Port = z_Port+Y_Cls_YZ*(z+((Norm(3)^2)/Norm(2)));
                        y_Port = Y_Cls_YZ*(Lft_y_LR*Lft+Rgt_y_LR*Rgt);
                        y_Port = y_Port+Z_Cls_YZ*(y+((Norm(2)^2)/Norm(3)));
                        PortalCtr = [x, y_Port, z_Port];
                    case 2 %%% X & Z are the closest
                        [~,Cls_XZ] = min([x_min,z_min]);
                        X_Cls_XZ = Cls_XZ==1; Z_Cls_XZ = Cls_XZ==2;
                        Norm = [z_min*((x_BF-1.5)*2),0,x_min*((z_BT-1.5)*2)];
                        x_Port = X_Cls_XZ*(Bck_x_BF*Bck+Frt_x_BF*Frt);
                        x_Port = x_Port+Z_Cls_XZ*(x+((Norm(1)^2)/Norm(3)));
                        z_Port = Z_Cls_XZ*(Btm_z_BT*Btm+Top_z_BT*Top);
                        z_Port = z_Port+X_Cls_XZ*(z+((Norm(3)^2)/Norm(1)));
                        PortalCtr = [x_Port,y,z_Port];
                    case 3 %%% X & Y are the closest
                        [~,Cls_XY] = min([x_min,y_min]);
                        X_Cls_XY = Cls_XY==1; Y_Cls_XY = Cls_XY==2;
                        Norm = [y_min*((x_BF-1.5)*2),x_min*((y_LR-1.5)*2),0];
                        x_Port = X_Cls_XY*(Bck_x_BF*Bck+Frt_x_BF*Frt);
                        x_Port = x_Port+Y_Cls_XY*(x+((Norm(1)^2)/Norm(2)));
                        y_Port = Y_Cls_XY*(Lft_y_LR*Lft+Rgt_y_LR*Rgt);
                        y_Port = y_Port+X_Cls_XY*(y+((Norm(2)^2)/Norm(1)));
                        PortalCtr = [x_Port,y_Port,z];
                end
                PortalBs = null(Norm);
                Dpts = zeros(3,cfg.numPortalpts+1);
                Ds = zeros(length(State.domain_map),cfg.numPortalpts+1);
                Thetas = linspace(0,(2*pi()-((2*pi())/cfg.numPortalpts)),cfg.numPortalpts);
                for j = 1:cfg.numPortalpts
                    Theta = Thetas(j);
                    cs = cos(Theta); sn = sin(Theta);
                    Dpts(:,j) = PortalCtr+cfg.PortalRad*cs*PortalBs(:,1)+cfg.PortalRad*sn*PortalBs(:,2);
                    Ds(1:3,j) = (Dpts(:,j)-State.MPLpt(1:3,4))./norm(Dpts(:,j)-State.MPLpt(1:3,4));
                end
                Dpts(:,end) = PortalCtr;
                Ds(1:3,end) = (Dpts(:,end)-State.MPLpt(1:3,4))./norm(Dpts(:,end)-State.MPLpt(1:3,4));
                State.target_cloud = Ds;
                State.target_cloud = Ds;
                break
            else
                State.Collision = 0;
            end
        otherwise
            State.Collision = 0;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SpherePlot(SphCtr,CurCtr,Vecs)
clf;
plot3(SphCtr(1),SphCtr(2),SphCtr(3),'ro');
hold on;
Base = CurCtr;
for i = 1:size(Vecs,2)
    End = Base+Vecs(1:3,i);
    plot3([Base(1) End(1)],[Base(2) End(2)],[Base(3) End(3)]);
end
xlabel('x'); ylabel('y'); zlabel('z');
xlim([0,1.5]);ylim([-1.5 1.5]);zlim([-1.5,1.5])
axis equal;
set(gca, 'CameraPosition', [0.5,-0.5,0.5],'CameraTarget',SphCtr');
set(gca, 'CameraViewAngle',120);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function FingPt_cmd = TranslCmdVel(CmdVel,State)
FingPt_cmd = zeros(6,1); %%% LINEAR AND ROTATIONAL VELOCITIES ONLY
LinVel = CmdVel(1:3);
RotVel = CmdVel(4:6);
FingPt_cmd(4:6) = RotVel;
FingPt_cmd(1:3) = LinVel+cross(RotVel,State.MPLEEtoFing');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out_cmd = FingtoEEVel(FingVel,State)
out_cmd = zeros(6,1);
LinVel = FingVel(1:3);
RotVel = FingVel(4:6);
out_cmd(4:6) = RotVel;
out_cmd(1:3) = LinVel+cross(RotVel,-(State.MPLEEtoFing'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function AvoidCtr = AvoidPt(State,cfg)
if State.HasDenso
    CurDensoOri = State.DensoPt(1:3,1:3);
    CurDensoLoc = State.DensoPt(1:3,4);
else
    CurDensoOri = cfg.FakeDensoPt(1:3,1:3);
    CurDensoLoc = cfg.FakeDensoPt(1:3,4);
end
AvoidCtr = zeros(4);
AvoidCtr(1:3,1:3) = CurDensoOri;
AvoidCtr(1:3,4) = CurDensoLoc+CurDensoOri*cfg.TargCtrOFFSET'
AvoidCtr(4,4) = 1;
%set(State.DensoHandle,'XData',[State.DensoPt(1,4) AvoidCtr(1,4)]);
%set(State.DensoHandle,'YData',[State.DensoPt(2,4) AvoidCtr(2,4)]);
%set(State.DensoHandle,'ZData',[State.DensoPt(3,4) AvoidCtr(3,4)]);
%set(State.MPL2DensoH, 'XData',[State.MPLpt(1,4) AvoidCtr(1,4)]);
%set(State.MPL2DensoH, 'YData',[State.MPLpt(2,4) AvoidCtr(2,4)]);
%set(State.MPL2DensoH, 'ZData',[State.MPLpt(3,4) AvoidCtr(3,4)]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function MPLpt = MPLtransEE(CurPos,CurOri,State)
MPLpt = zeros(4);
MPLpt(1:3,1:3) = CurOri;
MPLpt(1:3,4) = CurPos'+CurOri*State.MPLEEtoFing';
MPLpt(4,4) = 1;
CurPos
MPLpt(1:3,4)'

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function DensoPt = ProcDensoPt(TargLoc,TargOri)
DensoPt = zeros(4);
DensoPt(1:3,1:3) = MtxFrmXYZ(TargOri);
DensoPt(1:3,4) = TargLoc;
DensoPt(4,4) = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function SendCommand(output_cmd, incoming_data, tag)
outgoing_data = incoming_data;
outgoing_data.vel = output_cmd(:)';
outgoing_data.tag(1:length(tag)) = tag;
SendMessage('FIXTURED_COMPOSITE_MOVEMENT_COMMAND', outgoing_data);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Mtx = MtxFrmXYZ(Oris)
s1 = sin(Oris(1)); s2 = sin(Oris(2)); s3 = sin(Oris(3));
c1 = cos(Oris(1)); c2 = cos(Oris(2)); c3 = cos(Oris(3));
Mtx = zeros(3);
Mtx(1,1) = c2*c3; Mtx(1,2) = -c2*s3; Mtx(1,3) = s2;
Mtx(2,1) = c1*s3 + c3*s1*s2; Mtx(2,2) = c1*c3 - s1*s2*s3;
Mtx(2,3) = -c2*s1;
Mtx(3,1) = s1*s3 - c1*c3*s2; Mtx(3,2) = c1*s2*s3 + c3*s1;
Mtx(3,3) = c1*c2;
