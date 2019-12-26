function SendKnobConfig( )

% SendKnobConfig( )
%
% Sends configuration message to Knob Module

global XM;
global RTMA;

knob_config = XM.config.knob_config;
knob_config.use_robot_knob = int32(knob_config.use_robot_knob);
knob_config.fake_mode =      int32(knob_config.fake_mode);
knob_config.use_start_pad  = int32(RTMA.defines.(knob_config.use_start_pad));
knob_config.pad_steady_samples = int32(knob_config.pad_steady_samples);
SendMessage( 'KNOB_CONFIG', knob_config);
