function cfg = radar_config(cfg_path)
%RADAR_CONFIG 解析 TI Radar.cfg，并构建统一的雷达配置结构体。
%   输入：
%     cfg_path : char/string
%       TI mmWave Studio 或 SDK 导出的配置文件路径。
%
%   输出：
%     cfg : struct
%       cfg.source.ti_cfg_path
%       cfg.frame.*
%       cfg.rf.*
%       cfg.fft.*
%       cfg.metrics.*
%       cfg.mount.*
%       cfg.aoa.*
%       cfg.io.*
%
%   说明：
%     1. 所有参数都从当前这份 Radar.cfg 推导得到。
%     2. IWR6843ISK 的虚拟阵列会按实际 TX 时隙顺序重排，以便和
%        deinterleave_tdm_mimo 之后的 channel_response(:) 顺序一致。

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

    cfg.mount = struct();
    cfg.mount.height_m = 2.0;
    cfg.mount.pitch_down_deg = 15.0;
    cfg.mount.position_world_m = [0; 0; cfg.mount.height_m];
    cfg.mount.frame_convention = ...
        '世界坐标：x 为水平方位向，y 为水平前向，z 为竖直向上；原点在雷达到地面的垂足';

    cfg.aoa = local_build_iwr6843isk_aoa_cfg(cfg, raw);
    cfg.array_geometry = cfg.aoa.array_geometry;
    cfg.scan_cfg = cfg.aoa.scan_cfg;

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

function aoa_cfg = local_build_iwr6843isk_aoa_cfg(cfg, raw)
    lambda_half_m = cfg.rf.lambda_m / 2;

    % IWR6843ISK 的标准虚拟阵列，单位为 lambda/2，对应 [TX1, TX2, TX3]。
    canonical_x_hlambda = [ ...
        0, 1, 2, 3, ...
        2, 3, 4, 5, ...
        4, 5, 6, 7];
    canonical_z_hlambda = [ ...
        0, 0, 0, 0, ...
        1, 1, 1, 1, ...
        0, 0, 0, 0];
    canonical_tx_ids = [ ...
        ones(1, cfg.frame.num_rx), ...
        2 * ones(1, cfg.frame.num_rx), ...
        3 * ones(1, cfg.frame.num_rx)];
    canonical_rx_ids = repmat(1:cfg.frame.num_rx, 1, cfg.frame.num_tx);

    reorder_index = zeros(1, numel(canonical_tx_ids));
    write_offset = 0;
    for slot_idx = 1:numel(cfg.frame.actual_tx_order)
        tx_id = cfg.frame.actual_tx_order(slot_idx);
        block_index = find(canonical_tx_ids == tx_id);
        reorder_index(write_offset + (1:numel(block_index))) = block_index;
        write_offset = write_offset + numel(block_index);
    end

    slot_x_hlambda = canonical_x_hlambda(reorder_index).';
    slot_z_hlambda = canonical_z_hlambda(reorder_index).';
    slot_tx_ids = canonical_tx_ids(reorder_index).';
    slot_rx_ids = canonical_rx_ids(reorder_index).';

    azimuth_fov_deg = [-60, 60];
    elevation_fov_deg = [-15, 15];
    if isfield(raw, 'aoa')
        if ~isempty(raw.aoa.azimuth_fov_deg)
            azimuth_fov_deg = double(raw.aoa.azimuth_fov_deg);
        end
        if ~isempty(raw.aoa.elevation_fov_deg)
            elevation_fov_deg = double(raw.aoa.elevation_fov_deg);
        end
    end

    aoa_cfg = struct();
    aoa_cfg.board_name = 'IWR6843ISK';
    aoa_cfg.azimuth_fov_deg = azimuth_fov_deg;
    aoa_cfg.elevation_fov_deg = elevation_fov_deg;
    aoa_cfg.tx_time_offsets_s = (0:cfg.frame.num_tx-1) * cfg.rf.chirp_period_us * 1e-6;
    aoa_cfg.scan_cfg = struct( ...
        'azimuth_grid_deg', azimuth_fov_deg(1):2:azimuth_fov_deg(2), ...
        'elevation_grid_deg', elevation_fov_deg(1):2:elevation_fov_deg(2));
    aoa_cfg.array_geometry = struct( ...
        'element_positions_m', [ ...
            slot_x_hlambda * lambda_half_m, ...
            zeros(numel(slot_x_hlambda), 1), ...
            slot_z_hlambda * lambda_half_m], ...
        'element_positions_half_lambda', [ ...
            slot_x_hlambda, ...
            zeros(numel(slot_x_hlambda), 1), ...
            slot_z_hlambda], ...
        'tx_ids', slot_tx_ids, ...
        'rx_ids', slot_rx_ids, ...
        'tx_slot_order', cfg.frame.actual_tx_order(:), ...
        'channel_order_note', ...
            '各行与 channel_response(:) 一一对应：每个实际 TX 时隙内按 RX1..RXN 排列。');
    aoa_cfg.virtual_array_geometry = aoa_cfg.array_geometry;
    aoa_cfg.canonical_virtual_array_geometry = struct( ...
        'element_positions_m', [ ...
            canonical_x_hlambda(:) * lambda_half_m, ...
            zeros(numel(canonical_x_hlambda), 1), ...
            canonical_z_hlambda(:) * lambda_half_m], ...
        'element_positions_half_lambda', [ ...
            canonical_x_hlambda(:), ...
            zeros(numel(canonical_x_hlambda), 1), ...
            canonical_z_hlambda(:)], ...
        'tx_ids', canonical_tx_ids(:), ...
        'rx_ids', canonical_rx_ids(:), ...
        'tx_order', (1:cfg.frame.num_tx).');
end
