function fig = show_micro_doppler_map(micro_doppler_map, time_axis_s, doppler_axis_mps, visual_cfg, file_label)
%SHOW_MICRO_DOPPLER_MAP 显示微多普勒图。
%   输入：
%     micro_doppler_map : [doppler, frame]
%     time_axis_s : [frame, 1]
%     doppler_axis_mps : [doppler, 1]
%     visual_cfg : visual_config.m 输出
%     file_label : 图标题使用的文件名
%
%   当前默认显示策略为 dB 显示加自适应动态范围。

    display_map = micro_doppler_map;
    colorbar_label = 'Amplitude Sum';

    if isfield(visual_cfg, 'display_in_db') && visual_cfg.display_in_db
        display_map = local_to_db(display_map);
        display_map = display_map - max(display_map(:));
        colorbar_label = 'Power (dB)';
    end

    [cmin, cmax] = local_get_display_limits(display_map, visual_cfg);

    fig = figure('Name', 'Micro-Doppler Map', 'Color', 'w');
    imagesc(time_axis_s, doppler_axis_mps, display_map, [cmin, cmax]);
    axis xy;
    xlabel('Time (s)');
    ylabel('Doppler Velocity (m/s)');
    title(sprintf('Micro-Doppler | %s', file_label), 'Interpreter', 'none');
    colormap(visual_cfg.colormap_name);
    cb = colorbar;
    ylabel(cb, colorbar_label);
    grid on;
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