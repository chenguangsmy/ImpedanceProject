# ImpedanceProject
The data analysis, project design code for the 2D impedance project. For more project information, refer to the google doc procedure and relevant proposals.

## Folder structure overview:
###### DataAnalysis: 
the preliminary analysis code that aligned the data and save the needed information in the output file. Simple plotting functions
Flow order: FindMaxOnsetIndex - CheckDirectionReading - ForceData or
PositionData - Plot ForceData
- Main: 
        the main file to run that will initialize global variables to
        store the results, indicate if plots should be drawn, construct the
        condition index array as the current experiment setting, clean up and
        save processed data, plot the force data per condition.
- FindMaxOnsetIndex: 
        finding the max relative movement onset index per
        trial (how many sample does it take from beginning of the trial to the
        first movement onset). Only need to be run once per experiment.
- CheckDirectionReading: 
        need to run once per condition. Pull out the
        indexes to use in the big data array, arrange them in an array where
        each row corresponds to the indexes of one trial. The trials are in
        order: all trials in first repetition listed before next repetition,
        etc.
- ForceData: 
        using the index to find the corresponding force at the
        sampling time, aline the data at movement onset time, arrange the data
        in alingedPosByBlock in order: allTrials for forceX, then forceY, then
        Fz, TorqueX,Y,Z; Save the processed data to the corresponding index in
        the final output variables.
- PlotForceData: 
        plot the force for all directions per condition, 24
        plots total
- PlotForceDataByGroup: 
        not completed yet.
- PositionData: 
        clean up and aline the position data, in a seminar
        fashion as the ForceData


__Results__: sample results, mostly plots in jpg format

__PartsDesign__: solid work and 3d printer Code for the parts printed

__src__: main folder for experiment modules

__Proficio_External__: robotic arm control code

__data_loader__: code that translates the RTMS message to the saved data
format. Invoked by the ProcessRawData common when running in
matlab-shell under rg2/scripts

__config__: key configuration files used by the experiment, specifying task conditions, force threshold, each state time, pass/fail conditions, reward levels, etc.

__CerebusButtonReward.m__: The main matlab function to send reward. Normally under Documents/Matlab on the rig.
