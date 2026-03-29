function [filtered_cloud, valid_mask] = prefilter_human_roi(point_cloud, cfg)
%PREFILTER_HUMAN_ROI 根据房间 ROI、z、range、snr 进行人体预筛选。
% 函数签名：
%   [filtered_cloud, valid_mask] = prefilter_human_roi(point_cloud, cfg)
%
% 输入：
%   point_cloud : struct
%       需至少包含 point_cloud.xyz。
%   cfg : struct
%       cluster_config.m 输出。
%
% 输出：
%   filtered_cloud : struct
%       与输入点云结构一致，仅保留通过预筛选的点。
%   valid_mask : logical [N,1]
%       每个输入点是否通过筛选。

    filtered_cloud = local_empty_cloud();
    valid_mask = false(0, 1);

    if ~isstruct(point_cloud) || ~isfield(point_cloud, 'xyz') || isempty(point_cloud.xyz)
        return;
    end

    xyz = point_cloud.xyz;
    num_points = size(xyz, 1);
    valid_mask = true(num_points, 1);

    valid_mask = valid_mask & xyz(:, 1) >= cfg.room_roi_x_m(1) & xyz(:, 1) <= cfg.room_roi_x_m(2);
    valid_mask = valid_mask & xyz(:, 2) >= cfg.room_roi_y_m(1) & xyz(:, 2) <= cfg.room_roi_y_m(2);
    valid_mask = valid_mask & xyz(:, 3) >= cfg.room_roi_z_m(1) & xyz(:, 3) <= cfg.room_roi_z_m(2);

    if isfield(point_cloud, 'range_m') && numel(point_cloud.range_m) == num_points
        range_m = point_cloud.range_m(:);
    else
        range_m = sqrt(sum(xyz.^2, 2));
    end
    valid_mask = valid_mask & range_m >= cfg.range_gate_m(1) & range_m <= cfg.range_gate_m(2);

    if isfield(point_cloud, 'snr_db') && numel(point_cloud.snr_db) == num_points
        valid_mask = valid_mask & point_cloud.snr_db(:) >= cfg.min_snr_db;
    end

    if isfield(point_cloud, 'source_flag') && numel(point_cloud.source_flag) == num_points
        valid_mask = valid_mask & ismember(point_cloud.source_flag(:), cfg.allowed_source_flags(:));
    end

    filtered_cloud = local_select_cloud_rows(point_cloud, find(valid_mask));
end

function output_cloud = local_select_cloud_rows(input_cloud, row_idx)
    output_cloud = local_empty_cloud();
    if isempty(row_idx)
        return;
    end

    fields = fieldnames(input_cloud);
    num_points = size(input_cloud.xyz, 1);

    for field_idx = 1:numel(fields)
        field_name = fields{field_idx};
        field_value = input_cloud.(field_name);

        if isnumeric(field_value) || islogical(field_value)
            if isequal(size(field_value, 1), num_points)
                output_cloud.(field_name) = field_value(row_idx, :);
            else
                output_cloud.(field_name) = field_value;
            end
        else
            output_cloud.(field_name) = field_value;
        end
    end
end

function cloud = local_empty_cloud()
    cloud = struct();
    cloud.points = zeros(0, 7);
    cloud.xyz = zeros(0, 3);
    cloud.v_mps = zeros(0, 1);
    cloud.snr_db = zeros(0, 1);
    cloud.intensity = zeros(0, 1);
    cloud.source_flag = zeros(0, 1);
    cloud.range_m = zeros(0, 1);
    cloud.azimuth_deg = zeros(0, 1);
    cloud.elevation_deg = zeros(0, 1);
    cloud.range_bin = zeros(0, 1);
    cloud.doppler_bin = zeros(0, 1);
    cloud.doppler_mps = zeros(0, 1);
    cloud.power_linear = zeros(0, 1);
    cloud.power_db = zeros(0, 1);
end
