function cluster_result = cluster_human_points(point_cloud, cluster_cfg)
%CLUSTER_HUMAN_POINTS 对三维点云做 DBSCAN，并筛选人体候选簇。
%
% 输入：
%   point_cloud : struct
%       detections_to_point_cloud.m 输出的点云结构体。
%
%   cluster_cfg : struct
%       cluster_cfg.dbscan_epsilon_m
%       cluster_cfg.dbscan_min_points
%       cluster_cfg.valid_height_range_m
%       cluster_cfg.max_width_m
%       cluster_cfg.max_depth_m
%
% 输出：
%   cluster_result : struct
%       cluster_result.labels        [N, 1]
%       cluster_result.primary_label double
%       cluster_result.clusters      struct 数组
%
% 说明：
%   当 Statistics and Machine Learning Toolbox 可用时优先使用官方 dbscan，
%   否则回退到本文件末尾的简化实现。

    cluster_result = struct();
    cluster_result.labels = zeros(0, 1);
    cluster_result.primary_label = -1;
    cluster_result.clusters = struct([]);

    if isempty(point_cloud.xyz)
        return;
    end

    xyz = point_cloud.xyz;
    if size(xyz, 1) < cluster_cfg.dbscan_min_points
        cluster_result.labels = -ones(size(xyz, 1), 1);
        return;
    end

    if exist('dbscan', 'file') == 2
        labels = dbscan(xyz, cluster_cfg.dbscan_epsilon_m, cluster_cfg.dbscan_min_points);
    else
        labels = local_dbscan(xyz, cluster_cfg.dbscan_epsilon_m, cluster_cfg.dbscan_min_points);
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
        'mean_power_db', 0, ...
        'is_valid_human', false, ...
        'score', -inf), numel(valid_labels), 1);

    for idx = 1:numel(valid_labels)
        label = valid_labels(idx);
        members = find(labels == label);
        points_xyz = xyz(members, :);

        bbox_min = min(points_xyz, [], 1);
        bbox_max = max(points_xyz, [], 1);
        spans = bbox_max - bbox_min;
        height_m = spans(3);
        width_m = spans(1);
        depth_m = spans(2);

        is_valid_human = ...
            height_m >= cluster_cfg.valid_height_range_m(1) && ...
            height_m <= cluster_cfg.valid_height_range_m(2) && ...
            width_m <= cluster_cfg.max_width_m && ...
            depth_m <= cluster_cfg.max_depth_m;

        mean_power_db = mean(point_cloud.power_db(members));
        centroid = mean(points_xyz, 1);
        score = numel(members) + 0.05 * mean_power_db - 0.10 * norm(centroid(1:2));

        clusters(idx).label = label;
        clusters(idx).indices = members;
        clusters(idx).num_points = numel(members);
        clusters(idx).centroid = centroid;
        clusters(idx).bbox = [bbox_min; bbox_max];
        clusters(idx).width_m = width_m;
        clusters(idx).depth_m = depth_m;
        clusters(idx).height_m = height_m;
        clusters(idx).mean_power_db = mean_power_db;
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
