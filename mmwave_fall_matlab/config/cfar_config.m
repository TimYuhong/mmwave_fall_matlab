function cfg = cfar_config()
%CFAR_CONFIG 二维融合 RD 图上的 OS-CFAR 参数配置。
%   输出：
%     cfg.enable
%       是否启用 2D OS-CFAR。
%     cfg.train_cells_range
%       距离维上 CUT 两侧的训练单元数。
%     cfg.train_cells_doppler
%       多普勒维上 CUT 两侧的训练单元数。
%     cfg.guard_cells_range
%       距离维上 CUT 两侧的保护单元数。
%     cfg.guard_cells_doppler
%       多普勒维上 CUT 两侧的保护单元数。
%     cfg.rank_ratio
%       OS-CFAR 的分位比，取值范围为 (0, 1]。
%     cfg.threshold_scale
%       线性幅度域上的阈值缩放系数。
%     cfg.min_range_bin
%       小于该距离 bin 的近距离区域将被跳过。
%     cfg.max_range_bin
%       最大参与检测的距离 bin；Inf 表示不截断。
%
%   说明：
%     1. 当前流程先对 rd_cube 做非相干累积，再在融合后的二维 RD
%        幅度图上做 2D OS-CFAR。
%     2. 以下参数只是当前工程的经验起点，仍需结合实测数据继续调参。
    cfg = struct();
    cfg.enable = true;

    cfg.train_cells_range = 8;
    cfg.train_cells_doppler = 4;
    cfg.guard_cells_range = 2;
    cfg.guard_cells_doppler = 1;

    cfg.rank_ratio = 0.82;
    cfg.threshold_scale = 2.00;

    cfg.min_range_bin = 7;
    cfg.max_range_bin = inf;
end
