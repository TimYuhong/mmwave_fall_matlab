function [threshold_map, mask_map, detection_map] = os_cfar_2d(rd_linear_data, cfar_cfg)
%OS_CFAR_2D Run 2D OS-CFAR on a fused RD map or map stack.
%   [threshold_map, mask_map, detection_map] = os_cfar_2d(rd_linear_data, cfar_cfg)
%
%   Input:
%     rd_linear_data : numeric
%       1. [num_range_bins, num_doppler_bins] fused 2D RD amplitude map
%       2. [num_range_bins, num_doppler_bins, ...] map stack
%
%   Output:
%     threshold_map : numeric
%       Same size as rd_linear_data. Each CUT stores its OS-CFAR threshold.
%     mask_map : logical
%       Same size as rd_linear_data. true marks detected bins.
%     detection_map : numeric
%       Same size as rd_linear_data. Only detected amplitudes are retained.
%
%   Notes:
%     1. In the current main pipeline, the CFAR input is the fused 2D RD
%        amplitude map after noncoherent integration.
%     2. If a higher-dimensional map stack is passed in, this function runs
%        the same 2D OS-CFAR on each [range, doppler] slice independently.
    narginchk(2, 2);

    if isempty(rd_linear_data)
        threshold_map = zeros(size(rd_linear_data));
        mask_map = false(size(rd_linear_data));
        detection_map = zeros(size(rd_linear_data));
        return;
    end

    if ~isnumeric(rd_linear_data) || isvector(rd_linear_data)
        error('os_cfar_2d:InvalidInput', ...
            'rd_linear_data must be a numeric 2D map or [range, doppler, ...] array.');
    end

    input_size = size(rd_linear_data);
    if numel(input_size) < 2
        error('os_cfar_2d:InvalidDimension', ...
            'rd_linear_data must have at least range and doppler dimensions.');
    end

    if ismatrix(rd_linear_data)
        [threshold_map, mask_map, detection_map] = ...
            local_os_cfar_single_map(rd_linear_data, cfar_cfg);
        return;
    end

    num_range_bins = input_size(1);
    num_doppler_bins = input_size(2);
    num_maps = prod(input_size(3:end));

    rd_linear_stack = reshape(rd_linear_data, num_range_bins, num_doppler_bins, num_maps);
    threshold_stack = zeros(size(rd_linear_stack), 'like', rd_linear_stack);
    mask_stack = false(size(rd_linear_stack));
    detection_stack = zeros(size(rd_linear_stack), 'like', rd_linear_stack);

    for map_idx = 1:num_maps
        [current_threshold, current_mask, current_detection] = ...
            local_os_cfar_single_map(rd_linear_stack(:, :, map_idx), cfar_cfg);
        threshold_stack(:, :, map_idx) = current_threshold;
        mask_stack(:, :, map_idx) = current_mask;
        detection_stack(:, :, map_idx) = current_detection;
    end

    threshold_map = reshape(threshold_stack, input_size);
    mask_map = reshape(mask_stack, input_size);
    detection_map = reshape(detection_stack, input_size);
end

function [threshold_map, mask_map, detection_map] = local_os_cfar_single_map(rd_linear_map, cfar_cfg)
    map_size = size(rd_linear_map);
    threshold_map = zeros(map_size, 'like', rd_linear_map);
    mask_map = false(map_size);
    detection_map = zeros(map_size, 'like', rd_linear_map);

    if ~isfield(cfar_cfg, 'enable') || ~cfar_cfg.enable
        return;
    end

    num_range_bins = map_size(1);
    num_doppler_bins = map_size(2);

    train_r = cfar_cfg.train_cells_range;
    train_d = cfar_cfg.train_cells_doppler;
    guard_r = cfar_cfg.guard_cells_range;
    guard_d = cfar_cfg.guard_cells_doppler;
    rank_ratio = cfar_cfg.rank_ratio;
    threshold_scale = cfar_cfg.threshold_scale;
    min_range_bin = max(1, round(cfar_cfg.min_range_bin));

    if isinf(cfar_cfg.max_range_bin)
        max_range_bin = num_range_bins;
    else
        max_range_bin = min(num_range_bins, round(cfar_cfg.max_range_bin));
    end

    range_start = max(1 + train_r + guard_r, min_range_bin);
    range_stop = min(num_range_bins - train_r - guard_r, max_range_bin);
    doppler_start = 1 + train_d + guard_d;
    doppler_stop = num_doppler_bins - train_d - guard_d;

    if range_start > range_stop || doppler_start > doppler_stop
        return;
    end

    kernel_rows = 2 * (train_r + guard_r) + 1;
    kernel_cols = 2 * (train_d + guard_d) + 1;
    training_mask = true(kernel_rows, kernel_cols);
    training_mask((train_r + 1):(train_r + 2 * guard_r + 1), ...
                  (train_d + 1):(train_d + 2 * guard_d + 1)) = false;
    num_training_cells = nnz(training_mask);
    rank_index = max(1, min(num_training_cells, ceil(rank_ratio * num_training_cells)));

    for range_idx = range_start:range_stop
        range_slice = (range_idx - train_r - guard_r):(range_idx + train_r + guard_r);

        for doppler_idx = doppler_start:doppler_stop
            doppler_slice = (doppler_idx - train_d - guard_d):(doppler_idx + train_d + guard_d);
            window_cells = rd_linear_map(range_slice, doppler_slice);
            training_cells = window_cells(training_mask);
            sorted_cells = sort(training_cells(:), 'ascend');
            threshold_value = threshold_scale * sorted_cells(rank_index);

            threshold_map(range_idx, doppler_idx) = threshold_value;
            if rd_linear_map(range_idx, doppler_idx) > threshold_value
                mask_map(range_idx, doppler_idx) = true;
                detection_map(range_idx, doppler_idx) = rd_linear_map(range_idx, doppler_idx);
            end
        end
    end
end
