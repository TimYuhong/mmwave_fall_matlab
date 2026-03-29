function stable_cloud = accumulate_stable_points(history_clouds, stable_cfg)
%ACCUMULATE_STABLE_POINTS 对主人体簇做滑窗稳点累积。
%
% 输入：
%   history_clouds : cell
%       长度为 W 的 cell，每个元素是 extract_primary_human.m 输出的结构体。
%
%   stable_cfg : struct
%       stable_cfg.window_length_frames
%       stable_cfg.min_valid_frames
%       stable_cfg.voxel_size_m
%       stable_cfg.min_confidence
%
% 输出：
%   stable_cloud : struct
%       stable_cloud.xyz              [K, 3]
%       stable_cloud.confidence       [K, 1]
%       stable_cloud.num_valid_frames 标量
%       stable_cloud.reference_center [1, 3]
%
% 简化假设：
%   这里用“按簇质心对齐 + 体素出现频率”生成稳点，
%   未额外估计刚体姿态或骨架先验。

    stable_cloud = struct();
    stable_cloud.xyz = zeros(0, 3);
    stable_cloud.confidence = zeros(0, 1);
    stable_cloud.num_valid_frames = 0;
    stable_cloud.reference_center = [NaN, NaN, NaN];

    if isempty(history_clouds)
        return;
    end

    valid_mask = false(numel(history_clouds), 1);
    for idx = 1:numel(history_clouds)
        valid_mask(idx) = isstruct(history_clouds{idx}) && isfield(history_clouds{idx}, 'xyz') ...
            && ~isempty(history_clouds{idx}.xyz);
    end

    valid_clouds = history_clouds(valid_mask);
    if numel(valid_clouds) < stable_cfg.min_valid_frames
        return;
    end

    ref_cloud = valid_clouds{end};
    ref_center = ref_cloud.centroid;
    voxel_size = stable_cfg.voxel_size_m;

    all_voxels = zeros(0, 3);
    frame_owner = zeros(0, 1);

    for frame_idx = 1:numel(valid_clouds)
        cloud = valid_clouds{frame_idx};
        shift = ref_center - cloud.centroid;
        aligned_xyz = cloud.xyz + shift;

        voxel_idx = floor(aligned_xyz / voxel_size);
        voxel_idx = unique(voxel_idx, 'rows');

        all_voxels = [all_voxels; voxel_idx]; %#ok<AGROW>
        frame_owner = [frame_owner; frame_idx * ones(size(voxel_idx, 1), 1)]; %#ok<AGROW>
    end

    [unique_voxels, ~, voxel_group_idx] = unique(all_voxels, 'rows');
    counts = accumarray(voxel_group_idx, 1);
    confidence = counts / numel(valid_clouds);

    keep_mask = confidence >= stable_cfg.min_confidence;
    if ~any(keep_mask)
        return;
    end

    stable_cloud.xyz = (unique_voxels(keep_mask, :) + 0.5) * voxel_size;
    stable_cloud.confidence = confidence(keep_mask);
    stable_cloud.num_valid_frames = numel(valid_clouds);
    stable_cloud.reference_center = ref_center;
end
