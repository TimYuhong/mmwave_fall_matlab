function frame_cubes = reshape_frame_cube(adc_stream, radar_cfg)
%RESHAPE_FRAME_CUBE 按当前 Radar.cfg 将复数 ADC 流切成帧立方体。
%
% 输入：
%   adc_stream : complex 列向量
%       由 read_dca1000_adc.m 输出的复数 ADC 流。
%   radar_cfg  : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   frame_cubes : complex double
%       维度为 [num_adc_samples, num_rx, num_chirps_per_frame, num_frames]
%       的 4 维数据。
%
% 说明：
%   本函数严格模拟 process_data_v1.py / NumPy 的 C-order reshape 结果。
%   由于 MATLAB 是列主序、NumPy 默认是行主序，因此不能直接照抄
%   Python 的 reshape 维度顺序。
%
%   对应关系如下：
%   1. channel_interleave == 1 (Non-Interleaved)
%      Python: complex_data.reshape(F, C, R, S)
%      MATLAB 等价: reshape(flat, [S, R, C, F])
%
%   2. channel_interleave == 0 (Interleaved)
%      Python: complex_data.reshape(F, C, S, R).transpose(0,1,3,2)
%      MATLAB 等价: reshape(flat, [R, S, C, F]) -> permute([2,1,3,4])
%
%   最终统一输出维度：
%      [sample, rx, chirp, frame]

    samples_per_frame = prod(radar_cfg.io.frame_cube_shape);
    num_frames = floor(numel(adc_stream) / samples_per_frame);

    adc_stream = adc_stream(1:num_frames * samples_per_frame);

    num_samples = radar_cfg.rf.num_adc_samples;
    num_rx = radar_cfg.frame.num_rx;
    num_chirps = radar_cfg.frame.num_chirps_per_frame;

    if radar_cfg.io.channel_interleave == 0
        % Python:
        % complex_data.reshape(F, C, S, R).transpose(0,1,3,2)
        % MATLAB 等价先做 [R,S,C,F]，再交换前两维得到 [S,R,C,F]
        raw_cube = reshape(adc_stream, [num_rx, num_samples, num_chirps, num_frames]);
        frame_cubes = permute(raw_cube, [2, 1, 3, 4]);   % [sample, rx, chirp, frame]
    else
        % Python:
        % complex_data.reshape(F, C, R, S)
        % MATLAB 等价为 [S,R,C,F]
        frame_cubes = reshape(adc_stream, [num_samples, num_rx, num_chirps, num_frames]);
    end
end
