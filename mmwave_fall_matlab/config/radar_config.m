function cfg = radar_config(cfg_path)
%RADAR_CONFIG 解析 TI Radar.cfg，并生成项目统一雷达参数结构体。
%
% 输入：
%   cfg_path : char/string
%       TI mmWave Studio / SDK 导出的配置文件路径。
%
% 输出：
%   cfg : struct
%       统一雷达配置，关键字段如下：
%       cfg.source.ti_cfg_path
%       cfg.frame.num_rx
%       cfg.frame.num_tx
%       cfg.frame.num_loops
%       cfg.frame.num_chirps_per_frame
%       cfg.frame.actual_tx_order
%       cfg.frame.aoa_tx_order
%       cfg.frame.rx_order
%       cfg.rf.start_freq_ghz
%       cfg.rf.lambda_m
%       cfg.rf.freq_slope_hz_s
%       cfg.rf.num_adc_samples
%       cfg.rf.sample_rate_hz
%       cfg.fft.range_fft_size
%       cfg.fft.doppler_fft_size
%       cfg.metrics.range_resolution_m
%       cfg.metrics.max_range_m
%       cfg.metrics.doppler_resolution_mps
%       cfg.metrics.max_velocity_mps
%       cfg.io.complex_sample_order
%       cfg.io.frame_cube_shape
%
% 说明：
%   1. 本函数严格依据当前 Radar.cfg 的参数推导，不引入额外传感器假设。
%   2. AoA 前统一使用 [TX1, TX2, TX3] 的虚拟通道组顺序。

    if nargin < 1 || isempty(cfg_path)
        project_root = fileparts(fileparts(mfilename('fullpath')));
        cfg_path = fullfile(project_root, 'config', 'Radar.cfg');
    end

    raw = parse_ti_cfg(cfg_path);

    c0 = 299792458;

    cfg = struct();
    cfg.source = struct('ti_cfg_path', char(cfg_path));

    cfg.frame = struct();
    cfg.frame.num_rx = raw.channel.num_rx;
    cfg.frame.num_tx = raw.channel.num_tx;
    cfg.frame.num_loops = raw.frame.num_loops;
    cfg.frame.num_unique_chirps = raw.frame.num_unique_chirps;
    cfg.frame.num_chirps_per_frame = raw.frame.num_loops * raw.frame.num_unique_chirps;
    cfg.frame.frame_periodicity_ms = raw.frame.frame_periodicity_ms;
    cfg.frame.actual_tx_order = raw.frame.actual_tx_order;
    cfg.frame.aoa_tx_order = 1:raw.channel.num_tx;
    cfg.frame.rx_order = 1:raw.channel.num_rx;

    cfg.rf = struct();
    cfg.rf.start_freq_ghz = raw.profile.start_freq_ghz;
    cfg.rf.idle_time_us = raw.profile.idle_time_us;
    cfg.rf.adc_start_time_us = raw.profile.adc_start_time_us;
    cfg.rf.ramp_end_time_us = raw.profile.ramp_end_time_us;
    cfg.rf.freq_slope_mhz_us = raw.profile.freq_slope_mhz_us;
    cfg.rf.freq_slope_hz_s = raw.profile.freq_slope_mhz_us * 1e12;
    cfg.rf.num_adc_samples = raw.profile.num_adc_samples;
    cfg.rf.sample_rate_ksps = raw.profile.dig_out_sample_rate_ksps;
    cfg.rf.sample_rate_hz = raw.profile.dig_out_sample_rate_ksps * 1e3;
    cfg.rf.chirp_period_us = raw.profile.idle_time_us + raw.profile.ramp_end_time_us;
    cfg.rf.lambda_m = c0 / (raw.profile.start_freq_ghz * 1e9);

    cfg.fft = struct();
    cfg.fft.range_fft_size = raw.profile.num_adc_samples;
    cfg.fft.range_window = 'hann';
    cfg.fft.doppler_fft_size = raw.frame.num_loops;
    cfg.fft.doppler_window = 'hann';

    effective_bandwidth_hz = cfg.rf.freq_slope_hz_s * ...
        (cfg.rf.num_adc_samples / cfg.rf.sample_rate_hz);

    cfg.metrics = struct();
    cfg.metrics.range_resolution_m = c0 / (2 * effective_bandwidth_hz);
    cfg.metrics.max_range_m = cfg.rf.sample_rate_hz * c0 / (2 * cfg.rf.freq_slope_hz_s);
    cfg.metrics.doppler_resolution_mps = cfg.rf.lambda_m / ...
        (2 * cfg.frame.num_tx * cfg.frame.num_loops * cfg.rf.chirp_period_us * 1e-6);
    cfg.metrics.max_velocity_mps = cfg.rf.lambda_m / ...
        (4 * cfg.frame.num_tx * cfg.rf.chirp_period_us * 1e-6);

    cfg.io = struct();
    cfg.io.sample_swap = raw.adcbuf.sample_swap;
    cfg.io.channel_interleave = raw.adcbuf.channel_interleave;
    cfg.io.complex_sample_order = 'i_plus_jq_from_adcbuf';
    cfg.io.int_type = 'int16';
    cfg.io.frame_reshape_mode = 'mode_a';
    cfg.io.frame_cube_shape = [cfg.rf.num_adc_samples, ...
                               cfg.frame.num_rx, ...
                               cfg.frame.num_chirps_per_frame];
end
