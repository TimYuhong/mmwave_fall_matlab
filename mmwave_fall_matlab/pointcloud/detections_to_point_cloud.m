function point_cloud = detections_to_point_cloud(rd_cube, detection_list, radar_cfg, antenna_layout, aoa_cfg)
%DETECTIONS_TO_POINT_CLOUD 将 RD 检测点转换为三维人体点云。
%
% 输入：
%   rd_cube : complex double
%       维度 [num_range_bins, num_doppler_bins, num_rx, num_tx]
%
%   detection_list : double
%       维度 [N, 6]，由 dynamic_cfar_2d.m 输出：
%       [range_bin, doppler_bin, cut_power, noise_power, threshold, region_id]
%
%   radar_cfg      : struct
%   antenna_layout : struct
%   aoa_cfg        : struct
%
% 输出：
%   point_cloud : struct
%       point_cloud.xyz            [N, 3]
%       point_cloud.range_m        [N, 1]
%       point_cloud.doppler_mps    [N, 1]
%       point_cloud.azimuth_deg    [N, 1]
%       point_cloud.elevation_deg  [N, 1]
%       point_cloud.power_linear   [N, 1]
%       point_cloud.power_db       [N, 1]
%       point_cloud.range_bin      [N, 1]
%       point_cloud.doppler_bin    [N, 1]
%       point_cloud.region_id      [N, 1]

    point_cloud = local_empty_point_cloud();

    if isempty(detection_list)
        return;
    end

    num_det = size(detection_list, 1);
    xyz = zeros(num_det, 3);
    range_m = zeros(num_det, 1);
    doppler_mps = zeros(num_det, 1);
    azimuth_deg = zeros(num_det, 1);
    elevation_deg = zeros(num_det, 1);
    power_linear = zeros(num_det, 1);
    range_bin = detection_list(:, 1);
    doppler_bin = detection_list(:, 2);
    region_id = detection_list(:, 6);

    for det_idx = 1:num_det
        r_bin = detection_list(det_idx, 1);
        d_bin = detection_list(det_idx, 2);

        % 简化快拍构造：对当前 range-bin 的邻近 Doppler bin 作为快拍集合
        d_left = max(1, d_bin - 1);
        d_right = min(size(rd_cube, 2), d_bin + 1);
        snapshot_matrix = zeros(size(rd_cube, 3) * size(rd_cube, 4), d_right - d_left + 1);

        snap_write_idx = 1;
        for snap_d = d_left:d_right
            snapshot_matrix(:, snap_write_idx) = stack_virtual_channels(rd_cube, r_bin, snap_d);
            snap_write_idx = snap_write_idx + 1;
        end

        [~, ~, peak_info] = capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg);

        range_m(det_idx) = range_bin_to_meters(r_bin, radar_cfg);
        doppler_mps(det_idx) = doppler_bin_to_mps(d_bin, radar_cfg);
        azimuth_deg(det_idx) = peak_info.azimuth_deg;
        elevation_deg(det_idx) = peak_info.elevation_deg;
        [x, y, z] = sph2cart_points(range_m(det_idx), azimuth_deg(det_idx), elevation_deg(det_idx));
        xyz(det_idx, :) = [x, y, z];
        power_linear(det_idx) = detection_list(det_idx, 3);
    end

    point_cloud.xyz = xyz;
    point_cloud.range_m = range_m;
    point_cloud.doppler_mps = doppler_mps;
    point_cloud.azimuth_deg = azimuth_deg;
    point_cloud.elevation_deg = elevation_deg;
    point_cloud.power_linear = power_linear;
    point_cloud.power_db = 10 * log10(max(power_linear, eps));
    point_cloud.range_bin = range_bin;
    point_cloud.doppler_bin = doppler_bin;
    point_cloud.region_id = region_id;
end

function point_cloud = local_empty_point_cloud()
    point_cloud = struct();
    point_cloud.xyz = zeros(0, 3);
    point_cloud.range_m = zeros(0, 1);
    point_cloud.doppler_mps = zeros(0, 1);
    point_cloud.azimuth_deg = zeros(0, 1);
    point_cloud.elevation_deg = zeros(0, 1);
    point_cloud.power_linear = zeros(0, 1);
    point_cloud.power_db = zeros(0, 1);
    point_cloud.range_bin = zeros(0, 1);
    point_cloud.doppler_bin = zeros(0, 1);
    point_cloud.region_id = zeros(0, 1);
end
