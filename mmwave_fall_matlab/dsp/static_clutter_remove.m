function clutter_free_cube = static_clutter_remove(range_cube, clutter_cfg)
%STATIC_CLUTTER_REMOVE 对慢时间维执行静态杂波抑制。
%
% 函数签名：
%   clutter_free_cube = static_clutter_remove(range_cube, clutter_cfg)
%
% 输入：
%   range_cube : complex double
%       维度 [num_range_bins, num_loops, num_rx, num_tx]
%
%   clutter_cfg : struct
%       clutter_cfg.method : 'mean' / 'median'
%           'mean'   : 对慢时间维减去均值，适合大多数离线处理场景
%           'median' : 对慢时间维减去中值，对离群点更鲁棒
%
% 输出：
%   clutter_free_cube : complex double
%       维度与 range_cube 相同。
%
% 简化假设：
%   当前实现采用慢时间统计量估计静态背景，相当于抑制零 Doppler
%   及其附近的稳定杂波成分，未引入自适应背景更新模型。

    narginchk(2, 2);

    if isfield(clutter_cfg, 'method') && ~isempty(clutter_cfg.method)
        method = lower(string(clutter_cfg.method));
    else
        method = "mean";
    end

    switch method
        case "mean"
            clutter_est = mean(range_cube, 2);
        case "median"
            clutter_est = median(range_cube, 2);
        otherwise
            error('static_clutter_remove:UnsupportedMethod', ...
                '不支持的静态杂波抑制方法：%s', method);
    end

    clutter_free_cube = range_cube - clutter_est;
end
