function GiveDirectReward(level)

global RTMA;

reward_data = RTMA.MDF.GIVE_REWARD;
reward_data.duration_ms = 300;
reward_data.num_clicks = level;
if level > 0
  SendMessage( 'GIVE_REWARD', reward_data);
end