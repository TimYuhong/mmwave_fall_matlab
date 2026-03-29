function cfg = cluster_config()
%CLUSTER_CONFIG 人体 ROI 预筛选与 DBSCAN 配置。
% 输出：
%   cfg : struct
%       cfg.room_roi_x_m          : 房间 ROI 的 x 范围
%       cfg.room_roi_y_m          : 房间 ROI 的 y 范围
%       cfg.room_roi_z_m          : 房间 ROI 的 z 范围
%       cfg.range_gate_m          : 合理探测距离范围
%       cfg.min_snr_db            : 预筛选最小 SNR
%       cfg.allowed_source_flags  : 允许保留的 sourceFlag
%       cfg.dbscan_epsilon_m      : DBSCAN 邻域半径
%       cfg.dbscan_min_points     : DBSCAN 最小核心点数
%       cfg.min_cluster_points    : 人体簇最少点数
%       cfg.valid_height_range_m  : 合理人体高度范围
%       cfg.valid_width_range_m   : 合理人体宽度范围
%       cfg.valid_depth_range_m   : 合理人体深度范围
%       cfg.max_track_distance_m  : 与历史轨迹的最大关联距离
%       cfg.track_prefer_weight   : 轨迹连续性权重
%
% 调参建议：
%   eps 推荐初值 0.28~0.40 m；
%   minPts 推荐初值 6~12；
%   若人体点云较稀疏，可先增大 eps，再适度减小 minPts。

    cfg = struct();
    cfg.room_roi_x_m = [-2.2, 2.2];
    cfg.room_roi_y_m = [0.20, 5.50];
    cfg.room_roi_z_m = [-0.20, 2.20];
    cfg.range_gate_m = [0.30, 5.50];
    cfg.min_snr_db = 0;
    cfg.allowed_source_flags = [1, 2];

    cfg.dbscan_epsilon_m = 0.32;
    cfg.dbscan_min_points = 6;
    cfg.min_cluster_points = 8;
    cfg.valid_height_range_m = [0.15, 2.20];
    cfg.valid_width_range_m = [0.08, 1.50];
    cfg.valid_depth_range_m = [0.08, 2.00];
    cfg.max_track_distance_m = 1.20;
    cfg.track_prefer_weight = 0.80;
end
