%Author: Shuqi Liu 
%Date: 2019-12-27 17:06 
%File Description: Plot the position data. Plot the trajectory by
%condition, each row = 1 force and target distance configuration, each
%column = 1 reach direction in order right (-z), left (+z), forward (+y)
%and backward(-y).

figure('Name', 'Position Trajectory for All Conditions');
totalConditionTypes = 1;
rows = 1;
posRows = 3;
cols = 1;%totalConditionTypes / rows;

%TODO: it appears the pos is in order z,y,x, and they don't start from
%origin

for i = 1:totalConditionTypes
    fprintf('Plotting Condition: %d\n',i);
    subplot(rows,cols,i);
    hold on;
    %the data is in condition1, 2, 3,... order
    %plot x,y,z for the given condition
    start = (i-1)*blocks*posRows;
    %TODO?plot 3D doesn't really work here...
    plot3(AllPosAlignedByBlock(1, :),AllPosAlignedByBlock(16, :),AllPosAlignedByBlock(31, :));
%         plot3(AllPosAlignedByBlock(start+1:start+blocks, :),...
%         AllPosAlignedByBlock(start + blocks + 1 : start + 2*blocks, :),...
%         AllPosAlignedByBlock(start+2*blocks+1 : start + 3*blocks, :));
    %xlim([-2.5, 1]);
    %ylim([-15, 10]);
    xlabel('x');
    ylabel('y');
    zlabel('z');
    %the maxonsetIndex would be the time 0 point.
    %xline(0, '-.');
    %TODO: figure out the starting and ending target area in real
    %coordinates
    hold off;
end

% delete(findall(gcf,'type','annotation'));
% %top row title
% annotation('textbox', [.17,.93,.08,.05],'String','Right (-z)', ...
%     'EdgeColor', 'none' ,'FontSize', 20);
% annotation('textbox', [.38,.93,.08,.05],'String','Left (+z)', ...
%     'EdgeColor', 'none' ,'FontSize', 20);
% annotation('textbox', [.57,.93,.15,.05],'String','Forward (+y)', ...
%     'EdgeColor', 'none' ,'FontSize', 20);
% annotation('textbox', [.77,.93,.15,.05],'String','Backward (-y)', ...
%     'EdgeColor', 'none' ,'FontSize', 20);
% 
% %column wise title
% annotation('textbox', [.02,.85,.095,.06],'String','Low Fthreshold (2), Far Distance (0.06)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% annotation('textbox', [.02,.7,.095,.06],'String','Mid Fthreshold (5), Far Distance (0.06)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% annotation('textbox', [.02,.55,.099,.06],'String','High Fthreshold (8), Far Distance (0.06)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% annotation('textbox', [.015,.41,.12,.06],'String','Low Fthreshold (2), Close Distance (0.04)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% annotation('textbox', [.015,.28,.105,.06],'String','Mid Fthreshold (5), Close Distance (0.04)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% annotation('textbox', [.015,.13,.12,.06],'String','High Fthreshold (8), Close Distance (0.04)', ...
%     'EdgeColor', 'none' ,'FontSize', 12);
% 
% %TODO: some observations: pos not symmetrical around 0, x is around -0.12, and y is around 0.5
% titleName = append('Session ', sessionNum,' Position Trajectory');
% annotation('textbox', [.43, 0.01,.19,.04],'String',titleName, ...
%     'EdgeColor', 'none' ,'FontSize', 15, 'FontWeight', 'bold');