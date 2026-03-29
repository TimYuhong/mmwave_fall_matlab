function range_m = range_bin_to_meters(range_bin, radar_cfg)
%RANGE_BIN_TO_METERS 将 1-based 距离 bin 索引转换为实际距离（米）。
%
% 输入：
%   range_bin  : double / 向量
%       1-based 距离 bin 索引。
%   radar_cfg  : struct
%       radar_config.m 返回的配置结构体。
%
% 输出：
%   range_m    : double / 向量
%       与 range_bin 形状一致的距离值，单位米。

    range_m = (double(range_bin) - 1) * radar_cfg.metrics.range_resolution_m;
end
