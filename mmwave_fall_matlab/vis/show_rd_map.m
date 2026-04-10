function fig = show_rd_map(rd_amplitude_map, range_axis_m, doppler_axis_mps, frame_index, visual_cfg, file_label, cfar_overlay)
%SHOW_RD_MAP Display a single-frame RD map.
%   fig = show_rd_map(rd_amplitude_map, range_axis_m, doppler_axis_mps, ...
%       frame_index, visual_cfg, file_label, cfar_overlay)
%
%   Input:
%     rd_amplitude_map : [range, doppler] fused RD amplitude map
%     range_axis_m     : [range, 1] range axis in meters
%     doppler_axis_mps : [doppler, 1] doppler axis in m/s
%     frame_index      : displayed frame index
%     visual_cfg       : visual_config output
%     file_label       : figure title label
%     cfar_overlay     : optional struct for RD detections
%
%   The RD map is shown with optional dB scaling and dynamic-range control.
%   If cfar_overlay is provided, detections are marked using circle markers.
    if nargin < 7
        cfar_overlay = struct();
    end

    start_bin = min(max(visual_cfg.skip_near_range_bins + 1, 1), numel(range_axis_m));
    display_map = rd_amplitude_map(start_bin:end, :);
    display_range_axis = range_axis_m(start_bin:end);
    colorbar_label = 'Amplitude';

    if isfield(visual_cfg, 'display_in_db') && visual_cfg.display_in_db
        display_map = local_to_db(display_map);
        if ~isempty(display_map)
            display_map = display_map - max(display_map(:));
        end
        colorbar_label = 'Power (dB)';
    end

    [cmin, cmax] = local_get_display_limits(display_map, visual_cfg);

    fig = figure('Name', sprintf('RD Map - Frame %d', frame_index), 'Color', 'w');
    imagesc(doppler_axis_mps, display_range_axis, display_map, [cmin, cmax]);
    axis xy;
    xlabel('Doppler Velocity (m/s)');
    ylabel('Range (m)');
    title(sprintf('RD Map | %s | Frame %d', file_label, frame_index), 'Interpreter', 'none');
    colormap(visual_cfg.colormap_name);
    cb = colorbar;
    ylabel(cb, colorbar_label);
    grid on;

    if local_has_overlay(cfar_overlay)
        hold on;
        plot(cfar_overlay.doppler_mps(:), cfar_overlay.range_m(:), 'o', ...
            'Color', cfar_overlay.color, ...
            'MarkerSize', cfar_overlay.marker_size, ...
            'LineWidth', cfar_overlay.line_width);
        hold off;
    end
end

function tf = local_has_overlay(cfar_overlay)
    tf = isstruct(cfar_overlay) && ...
        isfield(cfar_overlay, 'range_m') && ...
        isfield(cfar_overlay, 'doppler_mps') && ...
        ~isempty(cfar_overlay.range_m) && ...
        ~isempty(cfar_overlay.doppler_mps);
end

function map_db = local_to_db(input_map)
    map_db = 20 * log10(max(abs(input_map), eps));
end

function [cmin, cmax] = local_get_display_limits(display_map, visual_cfg)
    if isempty(display_map)
        cmin = 0;
        cmax = 1;
        return;
    end

    cmax = max(display_map(:));

    if isfield(visual_cfg, 'adaptive_dynamic_range') && visual_cfg.adaptive_dynamic_range
        valid_values = display_map(isfinite(display_map));
        if isempty(valid_values)
            cmin = cmax - 60;
            return;
        end

        percentile = 5;
        if isfield(visual_cfg, 'dynamic_range_percentile') && ~isempty(visual_cfg.dynamic_range_percentile)
            percentile = visual_cfg.dynamic_range_percentile;
        end

        floor_db = -60;
        if isfield(visual_cfg, 'dynamic_range_floor_db') && ~isempty(visual_cfg.dynamic_range_floor_db)
            floor_db = visual_cfg.dynamic_range_floor_db;
        end

        cmin = prctile(valid_values, percentile);
        cmin = max(cmin, floor_db);
    else
        if isfield(visual_cfg, 'display_in_db') && visual_cfg.display_in_db
            cmin = -60;
        else
            cmin = min(display_map(:));
        end
    end
end
