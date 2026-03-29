function [stable_mask, hit_count, confidence, threshold_count] = binary_integration_track(hit_matrix, cfg)
%BINARY_INTEGRATION_TRACK 根据滑窗命中次数判断稳定体素。
% 函数签名：
%   [stable_mask, hit_count, confidence, threshold_count] = binary_integration_track(hit_matrix, cfg)
%
% 输入：
%   hit_matrix : logical/double
%       维度 [num_voxel, window_len]，每列对应一帧体素是否命中。
%   cfg : struct
%       stable_config.m 输出。
%
% 输出：
%   stable_mask : logical [num_voxel,1]
%   hit_count : double [num_voxel,1]
%   confidence : double [num_voxel,1]
%   threshold_count : double

    if isempty(hit_matrix)
        stable_mask = false(0, 1);
        hit_count = zeros(0, 1);
        confidence = zeros(0, 1);
        threshold_count = 0;
        return;
    end

    hit_matrix = double(hit_matrix > 0);
    num_frames = size(hit_matrix, 2);
    hit_count = sum(hit_matrix, 2);
    confidence = hit_count / max(num_frames, 1);

    if cfg.occ_threshold <= 1
        threshold_count = ceil(cfg.occ_threshold * num_frames);
    else
        threshold_count = round(cfg.occ_threshold);
    end

    threshold_count = max(threshold_count, cfg.min_valid_frames);
    stable_mask = hit_count >= threshold_count;
end
