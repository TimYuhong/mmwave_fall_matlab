function cfg = visual_config()
%VISUAL_CONFIG 可视化相关配置。
% 输出：
%   cfg : struct
%       cfg.default_bin_path      : 默认可视化输入 bin
%       cfg.range_roi_m           : 微多普勒积分距离范围 [min, max]
%       cfg.skip_near_range_bins  : 显示与积分时忽略的近距离 bin 数
%       cfg.colormap_name         : 热图配色，默认 parula
%       cfg.enable_normalization  : 是否仅在显示时做归一化
%       cfg.normalization_method  : 归一化方式，当前支持 'max'
%       cfg.preferred_frame_index : 期望展示的帧序号，空表示自动选择
%       cfg.save_figures          : 是否保存图片
%       cfg.output_dir            : 图片输出目录

    cfg = struct();
    cfg.default_bin_path = 'F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin';
    cfg.range_roi_m = [0.30, 5.00];
    cfg.skip_near_range_bins = 6;
    cfg.colormap_name = 'parula';
    cfg.enable_normalization = true;
    cfg.normalization_method = 'max';
    cfg.preferred_frame_index = [];
    cfg.save_figures = false;
    cfg.output_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
end
