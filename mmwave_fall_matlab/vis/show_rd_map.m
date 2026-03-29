function fig = show_rd_map(rd_amplitude_map, range_axis_m, doppler_axis_mps, frame_index, visual_cfg, file_label)
%SHOW_RD_MAP 显示单帧 RD 图。
% 输入：
%   rd_amplitude_map  : [range, doppler]
%   range_axis_m      : [range, 1]
%   doppler_axis_mps  : [doppler, 1]
%   frame_index       : 标量
%   visual_cfg        : visual_config.m 输出
%   file_label        : 图标题用文件名

    start_bin = min(max(visual_cfg.skip_near_range_bins + 1, 1), numel(range_axis_m));
    display_map = rd_amplitude_map(start_bin:end, :);
    display_range_axis = range_axis_m(start_bin:end);
    colorbar_label = 'Amplitude';

    if isfield(visual_cfg, 'enable_normalization') && visual_cfg.enable_normalization
        display_map = local_normalize_map(display_map, visual_cfg);
        colorbar_label = 'Normalized Amplitude';
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
% 仅用于显示层归一化，不修改上游原始幅度数据。
    normalized_map = input_map;

    if isempty(input_map)
        return;
    end

    switch lower(visual_cfg.normalization_method)
        case 'max'
            scale = max(abs(input_map(:)));
        otherwise
            error('show_rd_map:UnsupportedNormalization', ...
                '不支持的归一化方式：%s', visual_cfg.normalization_method);
    end

    if scale > 0
        normalized_map = input_map ./ scale;
    end
end
