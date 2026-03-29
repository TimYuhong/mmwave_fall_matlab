function cfg = cfar_config(radar_cfg)
%CFAR_CONFIG 生成分区动态 2D CFAR 配置。
%
% 输入：
%   radar_cfg : struct
%       由 radar_config.m 返回的配置结构体。
%
% 输出：
%   cfg : struct
%       cfg.zero_doppler_guard : double，零 Doppler 保护带宽
%       cfg.enable_local_peak  : logical，是否只保留局部峰
%       cfg.regions            : struct 数组，字段包括
%           .name
%           .range_bin_start
%           .range_bin_end
%           .training_cells    [range_train, doppler_train]
%           .guard_cells       [range_guard, doppler_guard]
%           .threshold_scale_db
%           .min_absolute_power

    range_res = radar_cfg.metrics.range_resolution_m;
    total_range_bins = radar_cfg.fft.range_fft_size;

    near_end = min(total_range_bins, max(8, round(1.2 / range_res)));
    mid_end = min(total_range_bins, max(near_end + 1, round(3.2 / range_res)));

    cfg = struct();
    cfg.zero_doppler_guard = 1;
    cfg.enable_local_peak = true;

    cfg.regions = repmat(struct( ...
        'name', '', ...
        'range_bin_start', 1, ...
        'range_bin_end', 1, ...
        'training_cells', [8, 4], ...
        'guard_cells', [2, 1], ...
        'threshold_scale_db', 15, ...
        'min_absolute_power', 0), 3, 1);

    cfg.regions(1).name = 'near_clutter';
    cfg.regions(1).range_bin_start = 2;
    cfg.regions(1).range_bin_end = near_end;
    cfg.regions(1).training_cells = [10, 6];
    cfg.regions(1).guard_cells = [3, 2];
    cfg.regions(1).threshold_scale_db = 18;
    cfg.regions(1).min_absolute_power = 1e2;

    cfg.regions(2).name = 'mid_human_roi';
    cfg.regions(2).range_bin_start = near_end + 1;
    cfg.regions(2).range_bin_end = mid_end;
    cfg.regions(2).training_cells = [8, 4];
    cfg.regions(2).guard_cells = [2, 1];
    cfg.regions(2).threshold_scale_db = 15;
    cfg.regions(2).min_absolute_power = 10;

    cfg.regions(3).name = 'far_low_snr';
    cfg.regions(3).range_bin_start = mid_end + 1;
    cfg.regions(3).range_bin_end = total_range_bins;
    cfg.regions(3).training_cells = [12, 6];
    cfg.regions(3).guard_cells = [3, 2];
    cfg.regions(3).threshold_scale_db = 12;
    cfg.regions(3).min_absolute_power = 1;
end
