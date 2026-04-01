function fig = show_rd_map(rd_amplitude_map, range_axis_m, doppler_axis_mps, frame_index, visual_cfg, file_label)
%SHOW_RD_MAP Display a single RD map.

    start_bin = min(max(visual_cfg.skip_near_range_bins + 1, 1), numel(range_axis_m));
    display_map = rd_amplitude_map(start_bin:end, :);
    display_range_axis = range_axis_m(start_bin:end);
    colorbar_label = 'Amplitude';

    normalization_method = 'max';
    if isfield(visual_cfg, 'normalization_method') && ~isempty(visual_cfg.normalization_method)
        normalization_method = lower(visual_cfg.normalization_method);
    end

    if isfield(visual_cfg, 'enable_normalization') && visual_cfg.enable_normalization
        display_map = local_normalize_map(display_map, visual_cfg);
        if ~strcmp(normalization_method, 'none')
            colorbar_label = 'Normalized Amplitude';
        end
    end

    fig = figure('Name', sprintf('RD Map - Frame %d', frame_index), 'Color', 'w');
    imagesc(doppler_axis_mps, display_range_axis, display_map);
    axis xy;
    xlabel('Doppler Velocity (m/s)');
    ylabel('Range (m)');
    title(sprintf('RD Map | %s | Frame %d', file_label, frame_index), 'Interpreter', 'none');
    colormap(visual_cfg.colormap_name);
    cb = colorbar;
    ylabel(cb, colorbar_label);
    grid on;
end

function normalized_map = local_normalize_map(input_map, visual_cfg)
% Normalize only for display.
    normalized_map = input_map;

    if isempty(input_map)
        return;
    end

    switch lower(visual_cfg.normalization_method)
        case 'max'
            scale = max(abs(input_map(:)));
        case 'none'
            scale = 0;
        otherwise
            error('show_rd_map:UnsupportedNormalization', ...
                'Unsupported normalization method: %s', visual_cfg.normalization_method);
    end

    if scale > 0
        normalized_map = input_map ./ scale;
    end
end
