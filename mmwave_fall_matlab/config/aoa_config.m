function cfg = aoa_config()
%AOA_CONFIG 生成 Capon AoA 扫描配置。
%
% 输出：
%   cfg : struct
%       cfg.azimuth_scan_deg   : 行向量，方位角扫描网格（度）
%       cfg.elevation_scan_deg : 行向量，俯仰角扫描网格（度）
%       cfg.diagonal_loading   : double，对角加载系数
%       cfg.remove_mean        : logical，是否对快拍做均值去除

    cfg = struct();
    cfg.azimuth_scan_deg = -80:1:80;
    cfg.elevation_scan_deg = -40:1:40;
    cfg.diagonal_loading = 1e-2;
    cfg.remove_mean = false;
end
