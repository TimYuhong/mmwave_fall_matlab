function fig = show_micro_doppler_map(micro_doppler_map, time_axis_s, doppler_axis_mps, visual_cfg, file_label)
%SHOW_MICRO_DOPPLER_MAP 显示微多普勒图。
% 输入：
%   micro_doppler_map : [doppler, frame]
%   time_axis_s       : [frame, 1]
%   doppler_axis_mps  : [doppler, 1]
%   visual_cfg        : visual_config.m 输出
%   file_label        : 图标题用文件名

    display_map = micro_doppler_map;
    colorbar_label = 'Amplitude Sum';

    if isfield(visual_cfg, 'enable_normalization') && visual_cfg.enable_normalization
        display_map = local_normalize_map(display_map, visual_cfg);
        colorbar_label = 'Normalized Amplitude';
    end

    fig = figure('Name', 'Micro-Doppler Map', 'Color', 'w');
    imagesc(time_axis_s, doppler_axis_mps, display_map);
    axis xy;
    xlabel('Time (s)');
    ylabel('Doppler Velocity (m/s)');
    title(sprintf('Micro-Doppler | %s', file_label), 'Interpreter', 'none');
    colormap(visual_cfg.colormap_name);
    cb = colorbar;
    ylabel(cb, colorbar_label);
    grid on;
end

function normalized_map = local_normalize_map(input_map, visual_cfg)
% 仅用于显示层归一化，不修改微多普勒原始积分结果。
    normalized_map = input_map;

    if isempty(input_map)
        return;
    end

    switch lower(visual_cfg.normalization_method)
        case 'max'
            scale = max(abs(input_map(:)));
        otherwise
            error('show_micro_doppler_map:UnsupportedNormalization', ...
                '不支持的归一化方式：%s', visual_cfg.normalization_method);
    end

    if scale > 0
        normalized_map = input_map ./ scale;
    end
end
