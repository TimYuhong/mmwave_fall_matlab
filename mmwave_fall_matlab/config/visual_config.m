function cfg = visual_config()
%VISUAL_CONFIG RD 图与微多普勒图的可视化配置。
%   输出：
%     cfg.default_bin_path
%       默认输入的 bin 文件路径。
%     cfg.range_roi_m
%       预留的距离 ROI，当前主流程未直接使用。
%     cfg.skip_near_range_bins
%       绘制 RD 图时跳过的近距离 bin 数。
%     cfg.colormap_name
%       热图配色名称。
%     cfg.display_in_db
%       是否使用 dB 方式显示。
%     cfg.adaptive_dynamic_range
%       是否启用自适应动态范围。
%     cfg.dynamic_range_floor_db
%       自适应动态范围的下限，不低于该值。
%     cfg.dynamic_range_percentile
%       自适应动态范围使用的分位数。
%     cfg.show_cfar_overlay
%       是否在 RD 图上叠加 CFAR 检测圈点。
%     cfg.cfar_overlay_mode
%       CFAR 圈点显示模式，例如 all 或 topk。
%     cfg.cfar_overlay_top_k
%       当显示模式为 topk 时最多显示的峰数。
%     cfg.cfar_overlay_color
%       圈点颜色。
%     cfg.cfar_overlay_marker_size
%       圈点大小。
%     cfg.cfar_overlay_line_width
%       圈点线宽。
%     cfg.preferred_frame_index
%       优先显示的帧序号。
%     cfg.save_figures
%       是否保存图片。
%     cfg.output_dir
%       图片输出目录。

    cfg = struct();
    cfg.default_bin_path = 'F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin';
    cfg.range_roi_m = [0.30, 5.50];
    cfg.skip_near_range_bins = 6;
    cfg.colormap_name = 'parula';

    % 显示策略：默认使用 dB 显示，并开启自适应动态范围。
    cfg.display_in_db = true;
    cfg.adaptive_dynamic_range = true;
    cfg.dynamic_range_floor_db = -60;
    cfg.dynamic_range_percentile = 5;

    cfg.show_cfar_overlay = true;
    cfg.cfar_overlay_mode = 'all';
    cfg.cfar_overlay_top_k = 20;
    cfg.cfar_overlay_color = [1, 0, 0];
    cfg.cfar_overlay_marker_size = 8;
    cfg.cfar_overlay_line_width = 1.2;

    cfg.preferred_frame_index = 82;
    cfg.save_figures = true;
    cfg.output_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
end
