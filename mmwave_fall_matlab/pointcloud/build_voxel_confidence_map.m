function voxel_map = build_voxel_confidence_map(history_clouds, cfg)
%BUILD_VOXEL_CONFIDENCE_MAP 将最近 W 帧人体点云累计到 voxel 网格。
% 函数签名：
%   voxel_map = build_voxel_confidence_map(history_clouds, cfg)
%
% 输入：
%   history_clouds : cell
%       最近若干帧的人体簇点云，每个元素应包含 xyz。
%   cfg : struct
%       stable_config.m 输出。
%
% 输出：
%   voxel_map : struct
%       voxel_map.voxel_index        [K,3]
%       voxel_map.voxel_center_xyz   [K,3]
%       voxel_map.hit_matrix         [K,W]
%       voxel_map.hit_count          [K,1]
%       voxel_map.confidence         [K,1]
%       voxel_map.stable_mask        [K,1]
%       voxel_map.stable_cloud       struct
%       voxel_map.num_valid_frames   标量
%       voxel_map.reference_center   [1,3]

    voxel_map = struct();
    voxel_map.voxel_index = zeros(0, 3);
    voxel_map.voxel_center_xyz = zeros(0, 3);
    voxel_map.hit_matrix = zeros(0, 0);
    voxel_map.hit_count = zeros(0, 1);
    voxel_map.confidence = zeros(0, 1);
    voxel_map.stable_mask = false(0, 1);
    voxel_map.stable_cloud = local_empty_stable_cloud();
    voxel_map.num_valid_frames = 0;
    voxel_map.reference_center = [NaN, NaN, NaN];

    if isempty(history_clouds)
        return;
    end

    history_clouds = history_clouds(max(1, numel(history_clouds) - cfg.window_length_frames + 1):end);
    valid_mask = false(numel(history_clouds), 1);
    for idx = 1:numel(history_clouds)
        valid_mask(idx) = isstruct(history_clouds{idx}) && isfield(history_clouds{idx}, 'xyz') ...
            && ~isempty(history_clouds{idx}.xyz);
    end

    valid_clouds = history_clouds(valid_mask);
    if numel(valid_clouds) < cfg.min_valid_frames
        return;
    end

    reference_center = local_get_reference_center(valid_clouds);
    frame_voxels = cell(numel(valid_clouds), 1);
    all_voxel_index = zeros(0, 3);

    for frame_idx = 1:numel(valid_clouds)
        xyz = valid_clouds{frame_idx}.xyz;

        if cfg.align_by_centroid && isfield(valid_clouds{frame_idx}, 'centroid') && ...
                all(isfinite(valid_clouds{frame_idx}.centroid))
            shift = reference_center - valid_clouds{frame_idx}.centroid;
            xyz = xyz + shift;
        end

        voxel_index = floor(xyz / cfg.voxel_size_m);
        voxel_index = unique(voxel_index, 'rows');
        frame_voxels{frame_idx} = voxel_index;
        all_voxel_index = [all_voxel_index; voxel_index]; %#ok<AGROW>
    end

    if isempty(all_voxel_index)
        return;
    end

    [unique_voxels, ~] = unique(all_voxel_index, 'rows');
    hit_matrix = zeros(size(unique_voxels, 1), numel(valid_clouds));

    for frame_idx = 1:numel(frame_voxels)
        [~, loc] = ismember(frame_voxels{frame_idx}, unique_voxels, 'rows');
        loc = loc(loc > 0);
        hit_matrix(loc, frame_idx) = 1;
    end

    [stable_mask, hit_count, confidence] = binary_integration_track(hit_matrix, cfg);
    voxel_center_xyz = (unique_voxels + 0.5) * cfg.voxel_size_m;

    stable_cloud = local_empty_stable_cloud();
    stable_cloud.xyz = voxel_center_xyz(stable_mask, :);
    stable_cloud.confidence = confidence(stable_mask);
    stable_cloud.hit_count = hit_count(stable_mask);
    stable_cloud.num_valid_frames = numel(valid_clouds);
    stable_cloud.reference_center = reference_center;

    voxel_map.voxel_index = unique_voxels;
    voxel_map.voxel_center_xyz = voxel_center_xyz;
    voxel_map.hit_matrix = hit_matrix;
    voxel_map.hit_count = hit_count;
    voxel_map.confidence = confidence;
    voxel_map.stable_mask = stable_mask;
    voxel_map.stable_cloud = stable_cloud;
    voxel_map.num_valid_frames = numel(valid_clouds);
    voxel_map.reference_center = reference_center;
end

function reference_center = local_get_reference_center(valid_clouds)
    reference_center = [NaN, NaN, NaN];
    last_cloud = valid_clouds{end};

    if isfield(last_cloud, 'centroid') && all(isfinite(last_cloud.centroid))
        reference_center = last_cloud.centroid;
    else
        reference_center = mean(last_cloud.xyz, 1);
    end
end

function stable_cloud = local_empty_stable_cloud()
    stable_cloud = struct();
    stable_cloud.xyz = zeros(0, 3);
    stable_cloud.confidence = zeros(0, 1);
    stable_cloud.hit_count = zeros(0, 1);
    stable_cloud.num_valid_frames = 0;
    stable_cloud.reference_center = [NaN, NaN, NaN];
end
