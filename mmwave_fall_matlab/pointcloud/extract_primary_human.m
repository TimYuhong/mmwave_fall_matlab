function human_cloud = extract_primary_human(point_cloud, cluster_result)
%EXTRACT_PRIMARY_HUMAN 从 DBSCAN 结果中提取主人体簇。
%
% 输入：
%   point_cloud    : struct
%       detections_to_point_cloud.m 输出点云结构体。
%   cluster_result : struct
%       cluster_human_points.m 输出结果。
%
% 输出：
%   human_cloud : struct
%       与 point_cloud 字段一致，但仅保留主人体簇中的点。
%       额外字段：
%       human_cloud.label
%       human_cloud.centroid
%       human_cloud.bbox

    human_cloud = local_empty_point_cloud();
    human_cloud.label = -1;
    human_cloud.centroid = [NaN, NaN, NaN];
    human_cloud.bbox = nan(2, 3);

    if isempty(point_cloud.xyz) || cluster_result.primary_label < 0
        return;
    end

    chosen = cluster_result.primary_label;
    members = find(cluster_result.labels == chosen);
    if isempty(members)
        return;
    end

    human_cloud.xyz = point_cloud.xyz(members, :);
    human_cloud.range_m = point_cloud.range_m(members);
    human_cloud.doppler_mps = point_cloud.doppler_mps(members);
    human_cloud.azimuth_deg = point_cloud.azimuth_deg(members);
    human_cloud.elevation_deg = point_cloud.elevation_deg(members);
    human_cloud.power_linear = point_cloud.power_linear(members);
    human_cloud.power_db = point_cloud.power_db(members);
    human_cloud.range_bin = point_cloud.range_bin(members);
    human_cloud.doppler_bin = point_cloud.doppler_bin(members);
    human_cloud.region_id = point_cloud.region_id(members);
    human_cloud.label = chosen;
    human_cloud.centroid = mean(human_cloud.xyz, 1);
    human_cloud.bbox = [min(human_cloud.xyz, [], 1); max(human_cloud.xyz, [], 1)];
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
