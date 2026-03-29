function cfg = mpoint_config(radar_cfg)
%MPOINT_CONFIG comprehensive mPoint 动静融合点云配置。
% 输入：
%   radar_cfg : struct
%       radar_config.m 返回的雷达参数结构体。
%
% 输出：
%   cfg : struct
%       cfg.range_window                : Range FFT 窗函数
%       cfg.doppler_window              : Doppler FFT 窗函数
%       cfg.mti_mode                    : 动态分支 MTI 方式，'diff' / 'mean'
%       cfg.min_range_m                 : 候选目标最小距离
%       cfg.max_range_m                 : 候选目标最大距离
%       cfg.skip_near_range_bins        : 近距离忽略 bin 数
%       cfg.dynamic_snapshot_half_width : 动态 AoA Doppler 邻域半宽
%       cfg.range_consistency_bins      : 动静分支 range 一致性阈值
%       cfg.angle_consistency_deg       : 动静分支角度一致性阈值
%       cfg.snr_consistency_db          : 动静分支 SNR 一致性阈值
%       cfg.dynamic_candidate_top_k     : 动态候选最多保留数
%       cfg.dynamic_min_snr_db          : 动态候选最小 SNR
%       cfg.static_min_snr_db           : 静态补点最小 SNR
%       cfg.direct_angle_half_width_deg : 直接 RAI 局部搜索角域半宽
%       cfg.static_peak_rel_db          : 相对主峰阈值
%       cfg.static_max_points_per_anchor: 每个动态锚点最多补点数
%       cfg.duplicate_distance_m        : 去重时的空间距离阈值
%       cfg.duplicate_velocity_mps      : 去重时的速度阈值
%       cfg.fallback_percentile         : CFAR 为空时的峰值百分位回退
%       cfg.rdi_cfar_cfg                : 动态分支 RDI 候选筛选配置

    cfg = struct();
    cfg.range_window = radar_cfg.fft.range_window;
    cfg.doppler_window = radar_cfg.fft.doppler_window;
    cfg.mti_mode = 'diff';
    cfg.min_range_m = 0.30;
    cfg.max_range_m = min(5.50, radar_cfg.metrics.max_range_m);
    cfg.skip_near_range_bins = 6;
    cfg.dynamic_snapshot_half_width = 1;
    cfg.range_consistency_bins = 1;
    cfg.angle_consistency_deg = 8;
    cfg.snr_consistency_db = 12;
    cfg.dynamic_candidate_top_k = 6;
    cfg.dynamic_min_snr_db = 6;
    cfg.static_min_snr_db = 2;
    cfg.direct_angle_half_width_deg = 10;
    cfg.static_peak_rel_db = -6;
    cfg.static_max_points_per_anchor = 12;
    cfg.duplicate_distance_m = 0.10;
    cfg.duplicate_velocity_mps = 0.25;
    cfg.fallback_percentile = 99.5;

    cfg.rdi_cfar_cfg = cfar_config(radar_cfg);
    cfg.rdi_cfar_cfg.zero_doppler_guard = 0;
end
