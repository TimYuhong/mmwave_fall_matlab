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
%       cfg.point_cloud_roi       : 点云显示ROI范围，固定坐标系
%       cfg.point_cloud_ground_z  : 地面高度（Z坐标原点）

    cfg = struct();
    cfg.default_bin_path = 'F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin';
    cfg.range_roi_m = [0.30, 5.00];
    cfg.skip_near_range_bins = 6;
    cfg.colormap_name = 'parula';
    cfg.enable_normalization = true;
    cfg.normalization_method = 'max';
    cfg.preferred_frame_index = [82];
    cfg.save_figures = false;
    cfg.output_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');

    % 雷达安装参数（用于坐标转换到地面坐标系）
    cfg.radar_mount = struct();
    cfg.radar_mount.height_m = 2.0;              % 雷达距地面高度 (m)
    cfg.radar_mount.tilt_deg = -30.0;            % 雷达俯仰角 (deg)，负值表示向下倾斜

    % 雷达FOV参数
    cfg.radar_fov = struct();
    cfg.radar_fov.azimuth_deg = [-60, 60];       % 方位角范围 (deg)
    cfg.radar_fov.elevation_deg = [-15, 15];     % 俯仰角范围 (deg)

    % 点云显示固定ROI配置（以地面为原点的固定坐标系）
    cfg.point_cloud_roi = struct();
    cfg.point_cloud_roi.x_range = [-3.0, 3.0];   % X轴范围 (m)，左右方向
    cfg.point_cloud_roi.y_range = [0.0, 5.5];    % Y轴范围 (m)，前向距离
    cfg.point_cloud_roi.z_range = [0.0, 3.0];    % Z轴范围 (m)，高度（地面为0）
    cfg.point_cloud_ground_z = 0.0;              % 地面Z坐标
end
