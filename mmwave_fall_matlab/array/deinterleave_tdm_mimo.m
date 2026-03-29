function mimo_cube = deinterleave_tdm_mimo(frame_cube, radar_cfg)
%DEINTERLEAVE_TDM_MIMO 按实际采集发射顺序拆分 TDM-MIMO chirp。
%
% 输入：
%   frame_cube : complex double
%       单帧 cube，维度 [num_adc_samples, num_rx, num_chirps_per_frame]
%   radar_cfg  : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   mimo_cube  : complex double
%       维度 [num_adc_samples, num_loops, num_rx, num_tx]
%       第 4 维顺序严格等于 Radar.cfg 中的实际采集顺序：
%       radar_cfg.frame.actual_tx_order。
%
% 说明：
%   当前 Radar.cfg 的实际发射顺序是 [TX1, TX3, TX2]，
%   本函数严格沿用 process_data_v1.py 的块顺序，不额外做任何重排。

    num_samples = size(frame_cube, 1);
    num_loops = radar_cfg.frame.num_loops;
    num_rx = radar_cfg.frame.num_rx;
    num_tx = radar_cfg.frame.num_tx;

    mimo_cube = zeros(num_samples, num_loops, num_rx, num_tx, 'like', frame_cube);

    for slot_idx = 1:num_tx
        chirp_indices = slot_idx:num_tx:radar_cfg.frame.num_chirps_per_frame;
        tx_cube = frame_cube(:, :, chirp_indices);   % [sample, rx, loop]
        mimo_cube(:, :, :, slot_idx) = permute(tx_cube, [1, 3, 2]);
    end
end
