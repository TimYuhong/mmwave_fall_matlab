function [point_cloud, debug_info] = gen_pointcloud_comprehensive_mpoint( ...
    mimo_cube, radar_cfg, antenna_layout, mpoint_cfg, aoa_cfg)
%GEN_POINTCLOUD_COMPREHENSIVE_MPOINT comprehensive mPoint 风格动静融合点云。
% 函数签名：
%   [point_cloud, debug_info] = gen_pointcloud_comprehensive_mpoint( ...
%       mimo_cube, radar_cfg, antenna_layout, mpoint_cfg, aoa_cfg)
%
% 输入：
%   mimo_cube : complex double
%       维度 [num_adc_samples, num_loops, num_rx, num_tx]。
%   radar_cfg : struct
%   antenna_layout : struct
%   mpoint_cfg : struct
%   aoa_cfg : struct
%
% 输出：
%   point_cloud.points         [N,7]，每行为 [x, y, z, v, snr, intensity, sourceFlag]
%   point_cloud.xyz            [N,3]
%   point_cloud.v_mps          [N,1]
%   point_cloud.snr_db         [N,1]
%   point_cloud.intensity      [N,1]
%   point_cloud.source_flag    [N,1]，1=动态分支点，2=静态补点点
%   point_cloud.range_m        [N,1]
%   point_cloud.azimuth_deg    [N,1]
%   point_cloud.elevation_deg  [N,1]
%   point_cloud.range_bin      [N,1]
%   point_cloud.doppler_bin    [N,1]
%   point_cloud.doppler_mps    [N,1]
%   point_cloud.power_linear   [N,1]
%   point_cloud.power_db       [N,1]
%
% 说明：
%   该模块先用动态分支给出人体所在的 range-angle 锚点，再在 direct RAI 中补回
%   近静止的人体表面散射。对跌倒后静止人体尤其有利，因为动态分支负责定位，
%   静态分支负责保留胸腹、躯干、腿部等低速或近静止表面反射，使点云更完整。

    narginchk(5, 5);

    [range_cube, ~] = range_fft(mimo_cube, struct( ...
        'fft_size', radar_cfg.fft.range_fft_size, ...
        'window_type', mpoint_cfg.range_window));

    dynamic_range_cube = local_apply_mti(range_cube, mpoint_cfg.mti_mode);
    [dynamic_rd_cube, ~] = doppler_fft(dynamic_range_cube, struct( ...
        'fft_size', radar_cfg.fft.doppler_fft_size, ...
        'window_type', mpoint_cfg.doppler_window, ...
        'apply_shift', true));

    rdi_power_map = squeeze(sum(sum(abs(dynamic_rd_cube).^2, 4), 3));
    [~, candidate_list] = dynamic_cfar_2d(rdi_power_map, mpoint_cfg.rdi_cfar_cfg);
    candidate_list = local_select_dynamic_candidates(candidate_list, rdi_power_map, radar_cfg, mpoint_cfg);

    point_cloud = local_empty_point_cloud();

    for candidate_idx = 1:size(candidate_list, 1)
        anchor = local_make_dynamic_anchor(candidate_list(candidate_idx, :), dynamic_rd_cube, ...
            radar_cfg, antenna_layout, aoa_cfg, mpoint_cfg);

        point_cloud = local_append_point(point_cloud, anchor, mpoint_cfg);

        static_points = local_extract_static_points(range_cube, anchor, radar_cfg, ...
            antenna_layout, aoa_cfg, mpoint_cfg);

        for static_idx = 1:numel(static_points)
            point_cloud = local_append_point(point_cloud, static_points(static_idx), mpoint_cfg);
        end
    end

    point_cloud = local_finalize_point_cloud(point_cloud);

    debug_info = struct();
    debug_info.range_cube = range_cube;
    debug_info.dynamic_range_cube = dynamic_range_cube;
    debug_info.dynamic_rd_cube = dynamic_rd_cube;
    debug_info.rdi_power_map = rdi_power_map;
    debug_info.dynamic_candidate_list = candidate_list;
end

function mti_cube = local_apply_mti(range_cube, mti_mode)
    switch lower(string(mti_mode))
        case "diff"
            mti_cube = cat(2, zeros(size(range_cube, 1), 1, size(range_cube, 3), size(range_cube, 4)), ...
                diff(range_cube, 1, 2));
        case "mean"
            mti_cube = range_cube - mean(range_cube, 2);
        otherwise
            error('gen_pointcloud_comprehensive_mpoint:UnsupportedMTI', ...
                '不支持的 MTI 方式：%s', mti_mode);
    end
end

function candidate_list = local_select_dynamic_candidates(candidate_list, rdi_power_map, radar_cfg, mpoint_cfg)
    if isempty(candidate_list)
        candidate_list = local_fallback_candidates(rdi_power_map, radar_cfg, mpoint_cfg);
    end

    if isempty(candidate_list)
        return;
    end

    keep_mask = false(size(candidate_list, 1), 1);
    for idx = 1:size(candidate_list, 1)
        range_bin = candidate_list(idx, 1);
        if range_bin > size(rdi_power_map, 1) || range_bin <= mpoint_cfg.skip_near_range_bins
            continue;
        end

        range_m = range_bin_to_meters(range_bin, radar_cfg);
        snr_db = 10 * log10(max(candidate_list(idx, 3), eps) / max(candidate_list(idx, 4), eps));
        if range_m < mpoint_cfg.min_range_m || range_m > mpoint_cfg.max_range_m
            continue;
        end
        if snr_db < mpoint_cfg.dynamic_min_snr_db
            continue;
        end

        keep_mask(idx) = true;
    end

    candidate_list = candidate_list(keep_mask, :);
    candidate_list = local_non_maximum_select(candidate_list, mpoint_cfg.dynamic_candidate_top_k, ...
        mpoint_cfg.range_consistency_bins, 1);

    if isempty(candidate_list)
        candidate_list = local_fallback_candidates(rdi_power_map, radar_cfg, mpoint_cfg);
        candidate_list = local_non_maximum_select(candidate_list, mpoint_cfg.dynamic_candidate_top_k, ...
            mpoint_cfg.range_consistency_bins, 1);
    end
end

function candidate_list = local_fallback_candidates(rdi_power_map, radar_cfg, mpoint_cfg)
    work_map = rdi_power_map;
    work_map(1:min(mpoint_cfg.skip_near_range_bins, size(work_map, 1)), :) = 0;

    valid_values = work_map(work_map > 0);
    if isempty(valid_values)
        candidate_list = zeros(0, 6);
        return;
    end

    power_threshold = prctile(valid_values, mpoint_cfg.fallback_percentile);
    noise_floor = median(valid_values);

    rows = [];
    cols = [];
    powers = [];

    for r = 2:(size(work_map, 1) - 1)
        for d = 2:(size(work_map, 2) - 1)
            cut_power = work_map(r, d);
            if cut_power < power_threshold
                continue;
            end

            neighborhood = work_map((r-1):(r+1), (d-1):(d+1));
            if cut_power < max(neighborhood(:))
                continue;
            end

            rows(end + 1, 1) = r; %#ok<AGROW>
            cols(end + 1, 1) = d; %#ok<AGROW>
            powers(end + 1, 1) = cut_power; %#ok<AGROW>
        end
    end

    if isempty(rows)
        candidate_list = zeros(0, 6);
        return;
    end

    candidate_list = [rows, cols, powers, ...
        noise_floor * ones(numel(rows), 1), ...
        power_threshold * ones(numel(rows), 1), ...
        zeros(numel(rows), 1)];

    [~, order] = sort(candidate_list(:, 3), 'descend');
    candidate_list = candidate_list(order, :);
end

function selected = local_non_maximum_select(candidate_list, top_k, range_guard, doppler_guard)
    selected = zeros(0, size(candidate_list, 2));

    for idx = 1:size(candidate_list, 1)
        current = candidate_list(idx, :);
        is_duplicate = false;

        for chosen_idx = 1:size(selected, 1)
            same_range = abs(current(1) - selected(chosen_idx, 1)) <= range_guard;
            same_doppler = abs(current(2) - selected(chosen_idx, 2)) <= doppler_guard;
            if same_range && same_doppler
                is_duplicate = true;
                break;
            end
        end

        if is_duplicate
            continue;
        end

        selected(end + 1, :) = current; %#ok<AGROW>
        if size(selected, 1) >= top_k
            break;
        end
    end
end

function anchor = local_make_dynamic_anchor(candidate_row, dynamic_rd_cube, radar_cfg, antenna_layout, aoa_cfg, mpoint_cfg)
    range_bin = candidate_row(1);
    doppler_bin = candidate_row(2);
    power_linear = candidate_row(3);
    noise_linear = max(candidate_row(4), eps);
    snr_db = 10 * log10(max(power_linear, eps) / noise_linear);

    snapshot_matrix = local_collect_dynamic_snapshots(dynamic_rd_cube, range_bin, doppler_bin, ...
        mpoint_cfg.dynamic_snapshot_half_width);
    [~, ~, peak_info] = capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg);

    range_m = range_bin_to_meters(range_bin, radar_cfg);
    velocity_mps = doppler_bin_to_mps(doppler_bin, radar_cfg);
    [x, y, z] = sph2cart_points(range_m, peak_info.azimuth_deg, peak_info.elevation_deg);

    anchor = struct();
    anchor.xyz = [x, y, z];
    anchor.v_mps = velocity_mps;
    anchor.snr_db = snr_db;
    anchor.intensity = power_linear;
    anchor.source_flag = 1;
    anchor.range_m = range_m;
    anchor.azimuth_deg = peak_info.azimuth_deg;
    anchor.elevation_deg = peak_info.elevation_deg;
    anchor.range_bin = range_bin;
    anchor.doppler_bin = doppler_bin;
end

function snapshot_matrix = local_collect_dynamic_snapshots(dynamic_rd_cube, range_bin, doppler_bin, half_width)
    left_bin = max(1, doppler_bin - half_width);
    right_bin = min(size(dynamic_rd_cube, 2), doppler_bin + half_width);
    num_snapshots = right_bin - left_bin + 1;
    num_virtual_ant = size(dynamic_rd_cube, 3) * size(dynamic_rd_cube, 4);
    snapshot_matrix = zeros(num_virtual_ant, num_snapshots);

    write_idx = 1;
    for doppler_idx = left_bin:right_bin
        snapshot_matrix(:, write_idx) = stack_virtual_channels(dynamic_rd_cube, range_bin, doppler_idx);
        write_idx = write_idx + 1;
    end
end

function static_points = local_extract_static_points(range_cube, anchor, radar_cfg, antenna_layout, aoa_cfg, mpoint_cfg)
    static_points = repmat(local_empty_point_record(), 0, 1);
    az_grid = aoa_cfg.azimuth_scan_deg(:);
    el_grid = aoa_cfg.elevation_scan_deg(:);
    max_points = mpoint_cfg.static_max_points_per_anchor;

    range_start = max(1, anchor.range_bin - mpoint_cfg.range_consistency_bins);
    range_end = min(size(range_cube, 1), anchor.range_bin + mpoint_cfg.range_consistency_bins);

    for range_bin = range_start:range_end
        snapshot_matrix = local_collect_direct_snapshots(range_cube, range_bin);
        [~, ~, ~, direct_rai] = capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg);

        angle_mask = abs(az_grid.' - anchor.azimuth_deg) <= mpoint_cfg.direct_angle_half_width_deg & ...
                     abs(el_grid - anchor.elevation_deg) <= mpoint_cfg.direct_angle_half_width_deg;

        local_rai = direct_rai;
        local_rai(~angle_mask) = 0;
        local_noise = local_robust_noise(local_rai(angle_mask));
        peak_list = local_find_local_peaks(local_rai, mpoint_cfg.static_peak_rel_db, max_points);

        for peak_idx = 1:numel(peak_list)
            peak = peak_list(peak_idx);
            peak_azimuth = az_grid(peak.azimuth_index);
            peak_elevation = el_grid(peak.elevation_index);
            peak_snr_db = 10 * log10(max(peak.power_linear, eps) / max(local_noise, eps));

            if abs(peak_snr_db - anchor.snr_db) > mpoint_cfg.snr_consistency_db
                continue;
            end

            if abs(peak_azimuth - anchor.azimuth_deg) > mpoint_cfg.angle_consistency_deg || ...
                    abs(peak_elevation - anchor.elevation_deg) > mpoint_cfg.angle_consistency_deg
                continue;
            end

            if peak_snr_db < mpoint_cfg.static_min_snr_db
                continue;
            end

            range_m = range_bin_to_meters(range_bin, radar_cfg);
            [x, y, z] = sph2cart_points(range_m, peak_azimuth, peak_elevation);

            static_point = struct();
            static_point.xyz = [x, y, z];
            static_point.v_mps = anchor.v_mps;
            static_point.snr_db = peak_snr_db;
            static_point.intensity = peak.power_linear;
            static_point.source_flag = 2;
            static_point.range_m = range_m;
            static_point.azimuth_deg = peak_azimuth;
            static_point.elevation_deg = peak_elevation;
            static_point.range_bin = range_bin;
            static_point.doppler_bin = anchor.doppler_bin;

            static_points(end + 1, 1) = static_point; %#ok<AGROW>
            if numel(static_points) >= max_points
                return;
            end
        end
    end
end

function snapshot_matrix = local_collect_direct_snapshots(range_cube, range_bin)
    slice = squeeze(range_cube(range_bin, :, :, :));   % [loops, rx, tx]
    slice = permute(slice, [2, 3, 1]);                 % [rx, tx, loops]
    snapshot_matrix = reshape(slice, size(slice, 1) * size(slice, 2), size(slice, 3));
end

function noise_floor = local_robust_noise(values)
    values = values(:);
    values = values(values > 0);
    if isempty(values)
        noise_floor = 1;
    else
        noise_floor = median(values);
    end
end

function peak_list = local_find_local_peaks(spectrum_2d, relative_threshold_db, max_count)
    if isempty(spectrum_2d) || ~any(spectrum_2d(:) > 0)
        peak_list = struct('azimuth_index', {}, 'elevation_index', {}, 'power_linear', {});
        return;
    end

    max_power = max(spectrum_2d(:));
    min_power = max_power * 10^(relative_threshold_db / 10);
    peak_list = repmat(struct('azimuth_index', 0, 'elevation_index', 0, 'power_linear', 0), 0, 1);

    for el_idx = 2:(size(spectrum_2d, 1) - 1)
        for az_idx = 2:(size(spectrum_2d, 2) - 1)
            cut_power = spectrum_2d(el_idx, az_idx);
            if cut_power < min_power
                continue;
            end

            neighborhood = spectrum_2d((el_idx-1):(el_idx+1), (az_idx-1):(az_idx+1));
            if cut_power < max(neighborhood(:))
                continue;
            end

            peak_info = struct();
            peak_info.azimuth_index = az_idx;
            peak_info.elevation_index = el_idx;
            peak_info.power_linear = cut_power;
            peak_list(end + 1, 1) = peak_info; %#ok<AGROW>
        end
    end

    if isempty(peak_list)
        return;
    end

    peak_power = arrayfun(@(p) p.power_linear, peak_list);
    [~, order] = sort(peak_power, 'descend');
    order = order(1:min(max_count, numel(order)));
    peak_list = peak_list(order);
end

function point_cloud = local_append_point(point_cloud, point_record, mpoint_cfg)
    if isempty(point_record) || ~isfield(point_record, 'xyz')
        return;
    end

    if ~isempty(point_cloud.xyz)
        distance_vec = sqrt(sum((point_cloud.xyz - point_record.xyz).^2, 2));
        velocity_vec = abs(point_cloud.v_mps - point_record.v_mps);
        duplicate_mask = distance_vec <= mpoint_cfg.duplicate_distance_m & ...
                         velocity_vec <= mpoint_cfg.duplicate_velocity_mps;
        if any(duplicate_mask)
            return;
        end
    end

    point_cloud.xyz(end + 1, :) = point_record.xyz;
    point_cloud.v_mps(end + 1, 1) = point_record.v_mps;
    point_cloud.snr_db(end + 1, 1) = point_record.snr_db;
    point_cloud.intensity(end + 1, 1) = point_record.intensity;
    point_cloud.source_flag(end + 1, 1) = point_record.source_flag;
    point_cloud.range_m(end + 1, 1) = point_record.range_m;
    point_cloud.azimuth_deg(end + 1, 1) = point_record.azimuth_deg;
    point_cloud.elevation_deg(end + 1, 1) = point_record.elevation_deg;
    point_cloud.range_bin(end + 1, 1) = point_record.range_bin;
    point_cloud.doppler_bin(end + 1, 1) = point_record.doppler_bin;
end

function point_cloud = local_finalize_point_cloud(point_cloud)
    point_cloud.doppler_mps = point_cloud.v_mps;
    point_cloud.power_linear = point_cloud.intensity;
    point_cloud.power_db = 10 * log10(max(point_cloud.intensity, eps));

    if isempty(point_cloud.xyz)
        point_cloud.points = zeros(0, 7);
    else
        point_cloud.points = [point_cloud.xyz, point_cloud.v_mps, ...
            point_cloud.snr_db, point_cloud.intensity, point_cloud.source_flag];
    end
end

function point_cloud = local_empty_point_cloud()
    point_cloud = struct();
    point_cloud.points = zeros(0, 7);
    point_cloud.xyz = zeros(0, 3);
    point_cloud.v_mps = zeros(0, 1);
    point_cloud.snr_db = zeros(0, 1);
    point_cloud.intensity = zeros(0, 1);
    point_cloud.source_flag = zeros(0, 1);
    point_cloud.range_m = zeros(0, 1);
    point_cloud.azimuth_deg = zeros(0, 1);
    point_cloud.elevation_deg = zeros(0, 1);
    point_cloud.range_bin = zeros(0, 1);
    point_cloud.doppler_bin = zeros(0, 1);
    point_cloud.doppler_mps = zeros(0, 1);
    point_cloud.power_linear = zeros(0, 1);
    point_cloud.power_db = zeros(0, 1);
end

function point_record = local_empty_point_record()
    point_record = struct();
    point_record.xyz = [0, 0, 0];
    point_record.v_mps = 0;
    point_record.snr_db = 0;
    point_record.intensity = 0;
    point_record.source_flag = 0;
    point_record.range_m = 0;
    point_record.azimuth_deg = 0;
    point_record.elevation_deg = 0;
    point_record.range_bin = 0;
    point_record.doppler_bin = 0;
end
