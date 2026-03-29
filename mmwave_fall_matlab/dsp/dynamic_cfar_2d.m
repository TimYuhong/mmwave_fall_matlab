function [detection_mask, detection_list, threshold_map, noise_map, region_map] = dynamic_cfar_2d(rd_power_map, cfar_cfg)
%DYNAMIC_CFAR_2D 分区动态 2D CFAR 检测。
%
% 函数签名：
%   [detection_mask, detection_list, threshold_map, noise_map, region_map] = ...
%       dynamic_cfar_2d(rd_power_map, cfar_cfg)
%
% 输入：
%   rd_power_map : double
%       维度 [num_range_bins, num_doppler_bins]，通常为非相干功率图。
%
%   cfar_cfg : struct
%       cfar_cfg.zero_doppler_guard : 零 Doppler 保护带宽
%       cfar_cfg.enable_local_peak  : 是否只保留局部极大值
%       cfar_cfg.regions            : struct 数组，每个元素包含：
%           .range_bin_start
%           .range_bin_end
%           .training_cells    [range_train, doppler_train]
%           .guard_cells       [range_guard, doppler_guard]
%           .threshold_scale_db
%           .min_absolute_power
%
% 输出：
%   detection_mask : logical
%       维度 [num_range_bins, num_doppler_bins]，检测结果掩码。
%
%   detection_list : double
%       维度 [N, 6]，每一行为：
%       [range_bin, doppler_bin, cut_power, noise_power, threshold, region_id]
%
%   threshold_map : double
%       每个 CUT 的动态阈值图。
%
%   noise_map : double
%       每个 CUT 的局部噪声估计图。
%
%   region_map : double
%       每个 CUT 所属的分区编号。
%
% 说明：
%   本函数不是固定阈值版本。每个距离分区都可以配置不同的
%   训练窗、保护窗和门限倍率，从而支持分区动态门限。

    narginchk(2, 2);

    [num_range_bins, num_doppler_bins] = size(rd_power_map);

    detection_mask = false(num_range_bins, num_doppler_bins);
    threshold_map = nan(num_range_bins, num_doppler_bins);
    noise_map = nan(num_range_bins, num_doppler_bins);
    region_map = zeros(num_range_bins, num_doppler_bins);

    center_doppler = floor(num_doppler_bins / 2) + 1;

    for region_id = 1:numel(cfar_cfg.regions)
        region = cfar_cfg.regions(region_id);

        train_r = region.training_cells(1);
        train_d = region.training_cells(2);
        guard_r = region.guard_cells(1);
        guard_d = region.guard_cells(2);

        row_start = max(region.range_bin_start, 1 + train_r + guard_r);
        row_end = min(region.range_bin_end, num_range_bins - train_r - guard_r);
        col_start = 1 + train_d + guard_d;
        col_end = num_doppler_bins - train_d - guard_d;

        for r = row_start:row_end
            for d = col_start:col_end
                % 零 Doppler 附近可选保护，减轻残余静态杂波
                if abs(d - center_doppler) <= cfar_cfg.zero_doppler_guard
                    continue;
                end

                row_idx = (r - train_r - guard_r):(r + train_r + guard_r);
                col_idx = (d - train_d - guard_d):(d + train_d + guard_d);
                local_block = rd_power_map(row_idx, col_idx);

                guard_row_range = (train_r + 1):(train_r + 2 * guard_r + 1);
                guard_col_range = (train_d + 1):(train_d + 2 * guard_d + 1);
                local_block(guard_row_range, guard_col_range) = NaN;

                training_cells = local_block(~isnan(local_block));
                if isempty(training_cells)
                    continue;
                end

                % 动态噪声估计：均值与中值取较大者，提升强杂波场景稳定性
                noise_mean = mean(training_cells);
                noise_median = median(training_cells);
                noise_power = max(noise_mean, noise_median);

                dynamic_threshold = max( ...
                    noise_power * 10^(region.threshold_scale_db / 10), ...
                    region.min_absolute_power);

                threshold_map(r, d) = dynamic_threshold;
                noise_map(r, d) = noise_power;
                region_map(r, d) = region_id;

                cut_power = rd_power_map(r, d);
                if cut_power <= dynamic_threshold
                    continue;
                end

                if cfar_cfg.enable_local_peak
                    neighborhood = rd_power_map((r-1):(r+1), (d-1):(d+1));
                    if cut_power < max(neighborhood(:))
                        continue;
                    end
                end

                detection_mask(r, d) = true;
            end
        end
    end

    [det_r, det_d] = find(detection_mask);
    num_det = numel(det_r);
    detection_list = zeros(num_det, 6);

    for idx = 1:num_det
        r = det_r(idx);
        d = det_d(idx);
        detection_list(idx, :) = [ ...
            r, ...
            d, ...
            rd_power_map(r, d), ...
            noise_map(r, d), ...
            threshold_map(r, d), ...
            region_map(r, d)];
    end

    if num_det > 0
        [~, order] = sort(detection_list(:, 3), 'descend');
        detection_list = detection_list(order, :);
    end
end
