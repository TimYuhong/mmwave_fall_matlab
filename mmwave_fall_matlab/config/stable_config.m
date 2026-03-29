function cfg = stable_config()
%STABLE_CONFIG 稳点 voxel 累计配置。
% 输出：
%   cfg : struct
%       cfg.window_length_frames : 滑窗长度 W
%       cfg.min_valid_frames     : 参与累计的最少有效帧数
%       cfg.voxel_size_m         : 体素边长
%       cfg.occ_threshold        : 稳定体素命中阈值
%       cfg.min_confidence       : 与 occ_threshold 对齐的置信度别名
%       cfg.align_by_centroid    : 是否按人体簇质心对齐后累计
%
% 调参建议：
%   voxelSize 推荐初值 0.06~0.12 m；
%   W 推荐初值 6~10；
%   T_occ 推荐初值 0.40~0.60。

    cfg = struct();
    cfg.window_length_frames = 8;
    cfg.min_valid_frames = 3;
    cfg.voxel_size_m = 0.08;
    cfg.occ_threshold = 0.50;
    cfg.min_confidence = cfg.occ_threshold;
    cfg.align_by_centroid = true;
end
