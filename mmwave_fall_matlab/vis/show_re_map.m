function fig = show_re_map(range_elevation_map, range_axis_m, elevation_axis_deg, frame_index, visual_cfg, file_label)
%SHOW_RE_MAP 显示单帧 Range-Elevation 热图。
% 输入：
%   range_elevation_map : [range, elevation]
%   range_axis_m        : [range, 1]
%   elevation_axis_deg  : [elevation, 1]
%   frame_index         : 标量
%   visual_cfg          : visual_config.m 输出
%   file_label          : 图标题用文件名

    start_bin = min(max(visual_cfg.skip_near_range_bins + 1, 1), numel(range_axis_m));
    display_map = range_elevation_map(start_bin:end, :);
    display_range_axis = range_axis_m(start_bin:end);
    colorbar_label = 'Amplitude';

    if isfield(visual_cfg, 'enable_normalization') && visual_cfg.enable_normalization
        display_map = local_normalize_map(display_map, visual_cfg);
        colorbar_label = 'Normalized Amplitude';
    end

    fig = figure('Name', sprintf('RE Map - Frame %d', frame_index), 'Color', 'w');
    imagesc(elevation_axis_deg, display_range_axis, display_map);
    axis xy;
    xlabel('Elevation (deg)');
    ylabel('Range (m)');
    title(sprintf('RE Map | %s | Frame %d', file_label, frame_index), 'Interpreter', 'none');
    colormap(visual_cfg.colormap_name);
    cb = colorbar;
    ylabel(cb, colorbar_label);
    grid on;
end

function normalized_map = local_normalize_map(input_map, visual_cfg)
% 仅用于显示层归一化，不修改上游 RE 原始幅度数据。
    normalized_map = input_map;

    if isempty(input_map)
        return;
    end

    switch lower(visual_cfg.normalization_method)
        case 'max'
            scale = max(abs(input_map(:)));
        otherwise
            error('show_re_map:UnsupportedNormalization', ...
                '不支持的归一化方式：%s', visual_cfg.normalization_method);
    end

    if scale > 0
        normalized_map = input_map ./ scale;
    end
end
