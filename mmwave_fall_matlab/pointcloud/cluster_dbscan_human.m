function [cluster_result, human_cloud, next_track_state] = cluster_dbscan_human(point_cloud, cfg, track_state)
%CLUSTER_DBSCAN_HUMAN 对人体候选点做 DBSCAN，并选出最可信的人体簇。
% 函数签名：
%   [cluster_result, human_cloud, next_track_state] = cluster_dbscan_human(point_cloud, cfg, track_state)
%
% 输入：
%   point_cloud : struct
%       预筛选后点云，至少包含 xyz。
%   cfg : struct
%       cluster_config.m 输出。
%   track_state : struct，可选
%       历史轨迹状态，若存在 centroid，则用于连续性打分。
%
% 输出：
%   cluster_result : struct
%       .labels         [N,1]
%       .primary_label  主人体簇标签
%       .clusters       候选簇属性数组
%   human_cloud : struct
%       主人体簇点云
%   next_track_state : struct
%       更新后的轨迹状态

    if nargin < 3 || isempty(track_state)
        track_state = struct('is_valid', false, 'centroid', [NaN, NaN, NaN]);
    end

    cluster_result = struct();
    cluster_result.labels = zeros(0, 1);
    cluster_result.primary_label = -1;
    cluster_result.clusters = struct([]);

    human_cloud = local_empty_cloud();
    human_cloud.label = -1;
    human_cloud.centroid = [NaN, NaN, NaN];
    human_cloud.bbox = nan(2, 3);

    next_track_state = track_state;

    if ~isstruct(point_cloud) || ~isfield(point_cloud, 'xyz') || isempty(point_cloud.xyz)
        next_track_state.is_valid = false;
        return;
    end

    xyz = point_cloud.xyz;
    if size(xyz, 1) < cfg.dbscan_min_points
        cluster_result.labels = -ones(size(xyz, 1), 1);
        next_track_state.is_valid = false;
        return;
    end

    if exist('dbscan', 'file') == 2
        labels = dbscan(xyz, cfg.dbscan_epsilon_m, cfg.dbscan_min_points);
    else
        labels = local_dbscan(xyz, cfg.dbscan_epsilon_m, cfg.dbscan_min_points);
    end

    cluster_result.labels = labels(:);
    valid_labels = unique(labels(labels > 0));

    clusters = repmat(struct( ...
        'label', 0, ...
        'indices', [], ...
        'num_points', 0, ...
        'centroid', [0, 0, 0], ...
        'bbox', zeros(2, 3), ...
        'width_m', 0, ...
        'depth_m', 0, ...
        'height_m', 0, ...
        'mean_snr_db', 0, ...
        'mean_intensity', 0, ...
        'track_distance_m', inf, ...
        'is_valid_human', false, ...
        'score', -inf), numel(valid_labels), 1);

    for idx = 1:numel(valid_labels)
        label = valid_labels(idx);
        member_idx = find(labels == label);
        member_xyz = xyz(member_idx, :);
        bbox_min = min(member_xyz, [], 1);
        bbox_max = max(member_xyz, [], 1);
        spans = bbox_max - bbox_min;

        height_m = spans(3);
        width_m = spans(1);
        depth_m = spans(2);
        centroid = mean(member_xyz, 1);

        if isfield(point_cloud, 'snr_db') && numel(point_cloud.snr_db) == size(xyz, 1)
            mean_snr_db = mean(point_cloud.snr_db(member_idx));
        else
            mean_snr_db = 0;
        end

        if isfield(point_cloud, 'intensity') && numel(point_cloud.intensity) == size(xyz, 1)
            mean_intensity = mean(point_cloud.intensity(member_idx));
        else
            mean_intensity = 0;
        end

        if isfield(track_state, 'is_valid') && track_state.is_valid && all(isfinite(track_state.centroid))
            track_distance_m = norm(centroid - track_state.centroid);
        else
            track_distance_m = 0;
        end

        is_valid_human = ...
            numel(member_idx) >= cfg.min_cluster_points && ...
            height_m >= cfg.valid_height_range_m(1) && height_m <= cfg.valid_height_range_m(2) && ...
            width_m >= cfg.valid_width_range_m(1) && width_m <= cfg.valid_width_range_m(2) && ...
            depth_m >= cfg.valid_depth_range_m(1) && depth_m <= cfg.valid_depth_range_m(2) && ...
            track_distance_m <= cfg.max_track_distance_m + eps;

        score = numel(member_idx) + 0.25 * mean_snr_db + 0.01 * mean_intensity ...
            - cfg.track_prefer_weight * track_distance_m;

        clusters(idx).label = label;
        clusters(idx).indices = member_idx;
        clusters(idx).num_points = numel(member_idx);
        clusters(idx).centroid = centroid;
        clusters(idx).bbox = [bbox_min; bbox_max];
        clusters(idx).width_m = width_m;
        clusters(idx).depth_m = depth_m;
        clusters(idx).height_m = height_m;
        clusters(idx).mean_snr_db = mean_snr_db;
        clusters(idx).mean_intensity = mean_intensity;
        clusters(idx).track_distance_m = track_distance_m;
        clusters(idx).is_valid_human = is_valid_human;
        clusters(idx).score = score;
    end

    cluster_result.clusters = clusters;

    valid_scores = -inf(numel(clusters), 1);
    for idx = 1:numel(clusters)
        if clusters(idx).is_valid_human
            valid_scores(idx) = clusters(idx).score;
        end
    end

    [best_score, best_idx] = max(valid_scores);
    if isfinite(best_score)
        cluster_result.primary_label = clusters(best_idx).label;
        human_cloud = local_select_cloud_rows(point_cloud, clusters(best_idx).indices);
        human_cloud.label = clusters(best_idx).label;
        human_cloud.centroid = clusters(best_idx).centroid;
        human_cloud.bbox = clusters(best_idx).bbox;
        next_track_state.is_valid = true;
        next_track_state.centroid = clusters(best_idx).centroid;
        next_track_state.label = clusters(best_idx).label;
    else
        next_track_state.is_valid = false;
    end
end

function labels = local_dbscan(xyz, epsilon, min_points)
    num_points = size(xyz, 1);
    labels = zeros(num_points, 1);
    visited = false(num_points, 1);
    cluster_id = 0;

    dist_mat = sqrt(sum((permute(xyz, [1, 3, 2]) - permute(xyz, [3, 1, 2])).^2, 3));

    for point_idx = 1:num_points
        if visited(point_idx)
            continue;
        end

        visited(point_idx) = true;
        neighbors = find(dist_mat(point_idx, :) <= epsilon);
        if numel(neighbors) < min_points
            labels(point_idx) = -1;
            continue;
        end

        cluster_id = cluster_id + 1;
        labels(point_idx) = cluster_id;
        seed_set = neighbors(:).';
        seed_cursor = 1;

        while seed_cursor <= numel(seed_set)
            neighbor_idx = seed_set(seed_cursor);

            if ~visited(neighbor_idx)
                visited(neighbor_idx) = true;
                neighbor_neighbors = find(dist_mat(neighbor_idx, :) <= epsilon);
                if numel(neighbor_neighbors) >= min_points
                    seed_set = unique([seed_set, neighbor_neighbors]); %#ok<AGROW>
                end
            end

            if labels(neighbor_idx) <= 0
                labels(neighbor_idx) = cluster_id;
            end

            seed_cursor = seed_cursor + 1;
        end
    end
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
            if size(field_value, 1) == num_points
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
