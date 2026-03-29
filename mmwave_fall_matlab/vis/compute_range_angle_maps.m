function angle_products = compute_range_angle_maps(frame_result, radar_cfg, antenna_layout, aoa_cfg, visual_cfg)
%COMPUTE_RANGE_ANGLE_MAPS 计算单帧的 RA 和 RE 热图。
% 输入：
%   frame_result    : struct
%       main_demo.m 单帧输出，要求包含 mpoint_debug.range_cube。
%   radar_cfg       : struct
%       radar_config.m 输出。
%   antenna_layout  : struct
%       get_isk_antenna_layout.m 输出。
%   aoa_cfg         : struct
%       aoa_config.m 输出。
%   visual_cfg      : struct
%       visual_config.m 输出。
%
% 输出：
%   angle_products : struct
%       .range_azimuth_map    [range, azimuth]
%       .range_elevation_map  [range, elevation]
%       .range_axis_m         [range, 1]
%       .azimuth_axis_deg     [azimuth, 1]
%       .elevation_axis_deg   [elevation, 1]

    angle_products = struct();
    angle_products.range_azimuth_map = zeros(0, 0);
    angle_products.range_elevation_map = zeros(0, 0);
    angle_products.range_axis_m = zeros(0, 1);
    angle_products.azimuth_axis_deg = aoa_cfg.azimuth_scan_deg(:);
    angle_products.elevation_axis_deg = aoa_cfg.elevation_scan_deg(:);

    if ~isfield(frame_result, 'mpoint_debug') || ~isfield(frame_result.mpoint_debug, 'range_cube') || ...
            isempty(frame_result.mpoint_debug.range_cube)
        return;
    end

    range_cube = frame_result.mpoint_debug.range_cube;
    num_range_bins = size(range_cube, 1);
    range_axis_m = range_bin_to_meters((1:num_range_bins).', radar_cfg);

    range_azimuth_map = zeros(num_range_bins, numel(angle_products.azimuth_axis_deg));
    range_elevation_map = zeros(num_range_bins, numel(angle_products.elevation_axis_deg));

    for range_bin = 1:num_range_bins
        if range_bin <= visual_cfg.skip_near_range_bins
            continue;
        end

        snapshot_matrix = local_collect_direct_snapshots(range_cube, range_bin);
        [azimuth_spectrum, elevation_spectrum] = capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg);
        range_azimuth_map(range_bin, :) = azimuth_spectrum.power_linear(:).';
        range_elevation_map(range_bin, :) = elevation_spectrum.power_linear(:).';
    end

    angle_products.range_azimuth_map = range_azimuth_map;
    angle_products.range_elevation_map = range_elevation_map;
    angle_products.range_axis_m = range_axis_m;
end

function snapshot_matrix = local_collect_direct_snapshots(range_cube, range_bin)
% 从 direct range cube 收集单个 range bin 的 AoA 快拍矩阵。
    slice = squeeze(range_cube(range_bin, :, :, :));   % [loops, rx, tx]
    slice = permute(slice, [2, 3, 1]);                 % [rx, tx, loops]
    snapshot_matrix = reshape(slice, size(slice, 1) * size(slice, 2), size(slice, 3));
end
