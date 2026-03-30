function fig = show_point_cloud_frame(frame_result, frame_index, file_label, visual_cfg)
%SHOW_POINT_CLOUD_FRAME 显示单帧点云、主人体簇和稳点点云。
%
% 输入：
%   frame_result : struct
%       main_demo.m 输出的单帧结果结构体。
%   frame_index  : 标量
%   file_label   : 图标题用文件名
%   visual_cfg   : struct (可选)
%       可视化配置，包含固定ROI范围。如果不传则使用默认配置。

    if nargin < 4 || isempty(visual_cfg)
        visual_cfg = visual_config();
    end

    fig = figure('Name', sprintf('Point Cloud - Frame %d', frame_index), 'Color', 'w');
    hold on;

    % 绘制地面参考平面（半透明）
    roi = visual_cfg.point_cloud_roi;
    ground_z = visual_cfg.point_cloud_ground_z;
    patch([roi.x_range(1), roi.x_range(2), roi.x_range(2), roi.x_range(1)], ...
          [roi.y_range(1), roi.y_range(1), roi.y_range(2), roi.y_range(2)], ...
          [ground_z, ground_z, ground_z, ground_z], ...
          [0.8, 0.8, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', [0.5, 0.5, 0.5], ...
          'DisplayName', 'Ground Plane');

    % 绘制ROI边界框
    draw_roi_box(roi, ground_z);

    % 绘制雷达FOV边界（投影到地面坐标系）
    draw_fov_boundary(visual_cfg.radar_mount, visual_cfg.radar_fov, roi);

    % 转换点云坐标：从雷达坐标系转换到地面坐标系
    if isfield(frame_result, 'point_cloud') && ~isempty(frame_result.point_cloud) ...
            && isfield(frame_result.point_cloud, 'xyz') && ~isempty(frame_result.point_cloud.xyz)
        xyz_ground = transform_radar_to_ground(frame_result.point_cloud.xyz, visual_cfg.radar_mount);
        scatter3(xyz_ground(:, 1), xyz_ground(:, 2), xyz_ground(:, 3), ...
                 28, [0.2, 0.55, 0.95], 'filled', 'DisplayName', 'All Detections');
    end

    if isfield(frame_result, 'human_cloud') && ~isempty(frame_result.human_cloud) ...
            && isfield(frame_result.human_cloud, 'xyz') && ~isempty(frame_result.human_cloud.xyz)
        xyz_ground = transform_radar_to_ground(frame_result.human_cloud.xyz, visual_cfg.radar_mount);
        scatter3(xyz_ground(:, 1), xyz_ground(:, 2), xyz_ground(:, 3), ...
                 36, [0.95, 0.35, 0.20], 'filled', 'DisplayName', 'Primary Human');
    end

    if isfield(frame_result, 'stable_cloud') && ~isempty(frame_result.stable_cloud) ...
            && isfield(frame_result.stable_cloud, 'xyz') && ~isempty(frame_result.stable_cloud.xyz)
        xyz_ground = transform_radar_to_ground(frame_result.stable_cloud.xyz, visual_cfg.radar_mount);
        scatter3(xyz_ground(:, 1), xyz_ground(:, 2), xyz_ground(:, 3), ...
                 42, [0.10, 0.70, 0.25], 'filled', 'DisplayName', 'Stable Cloud');
    end

    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    title(sprintf('Point Cloud | %s | Frame %d', file_label, frame_index), 'Interpreter', 'none');
    legend('Location', 'best');
    grid on;

    % 固定坐标轴范围（以地面为原点的固定ROI）
    xlim(roi.x_range);
    ylim(roi.y_range);
    zlim(roi.z_range);
    
    % 设置坐标轴等比例显示
    daspect([1, 1, 1]);
    
    view(35, 20);
    hold off;
end

function xyz_ground = transform_radar_to_ground(xyz_radar, radar_mount)
%TRANSFORM_RADAR_TO_GROUND 将雷达坐标系点云转换到地面坐标系。
%
% 雷达坐标系：X右，Y前，Z上（相对于雷达）
% 地面坐标系：X右，Y前，Z上（相对于地面，Z=0为地面）
%
% 输入：
%   xyz_radar   : Nx3 矩阵，雷达坐标系下的点云 [x, y, z]
%   radar_mount : struct
%       .height_m  : 雷达距地面高度 (m)
%       .tilt_deg  : 雷达俯仰角 (deg)，负值表示向下倾斜
%
% 输出：
%   xyz_ground  : Nx3 矩阵，地面坐标系下的点云

    if isempty(xyz_radar)
        xyz_ground = xyz_radar;
        return;
    end

    tilt_rad = deg2rad(radar_mount.tilt_deg);
    
    % 绕X轴旋转（俯仰变换）
    % 当雷达向下倾斜时，tilt_deg为负，需要将雷达坐标系的Y-Z平面旋转
    cos_t = cos(tilt_rad);
    sin_t = sin(tilt_rad);
    
    x_radar = xyz_radar(:, 1);
    y_radar = xyz_radar(:, 2);
    z_radar = xyz_radar(:, 3);
    
    % 旋转变换：绕X轴旋转 tilt_rad
    x_rot = x_radar;
    y_rot = y_radar * cos_t - z_radar * sin_t;
    z_rot = y_radar * sin_t + z_radar * cos_t;
    
    % 平移变换：雷达在地面上方 height_m 处
    xyz_ground = [x_rot, y_rot, z_rot + radar_mount.height_m];
end

function draw_roi_box(roi, ground_z)
%DRAW_ROI_BOX 绘制ROI边界框的边线
    x1 = roi.x_range(1); x2 = roi.x_range(2);
    y1 = roi.y_range(1); y2 = roi.y_range(2);
    z1 = roi.z_range(1); z2 = roi.z_range(2);
    
    edge_color = [0.3, 0.3, 0.3];
    line_width = 0.5;
    
    % 底面四条边
    plot3([x1, x2], [y1, y1], [z1, z1], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x2], [y1, y2], [z1, z1], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x1], [y2, y2], [z1, z1], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x1, x1], [y2, y1], [z1, z1], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    
    % 顶面四条边
    plot3([x1, x2], [y1, y1], [z2, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x2], [y1, y2], [z2, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x1], [y2, y2], [z2, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x1, x1], [y2, y1], [z2, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    
    % 四条竖直边
    plot3([x1, x1], [y1, y1], [z1, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x2], [y1, y1], [z1, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x2, x2], [y2, y2], [z1, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
    plot3([x1, x1], [y2, y2], [z1, z2], 'Color', edge_color, 'LineWidth', line_width, 'HandleVisibility', 'off');
end

function draw_fov_boundary(radar_mount, radar_fov, roi)
%DRAW_FOV_BOUNDARY 绘制雷达FOV边界在地面坐标系中的投影。
%
% 输入：
%   radar_mount : struct，雷达安装参数
%   radar_fov   : struct，雷达FOV参数
%   roi         : struct，ROI范围

    % 雷达位置（在地面坐标系中）
    radar_pos = [0, 0, radar_mount.height_m];
    
    % FOV边界角度
    az_min = deg2rad(radar_fov.azimuth_deg(1));
    az_max = deg2rad(radar_fov.azimuth_deg(2));
    el_min = deg2rad(radar_fov.elevation_deg(1));
    el_max = deg2rad(radar_fov.elevation_deg(2));
    tilt = deg2rad(radar_mount.tilt_deg);
    
    % 计算FOV四条边界线的方向向量（在雷达坐标系中）
    % 然后转换到地面坐标系
    max_range = max([roi.y_range(2), roi.z_range(2)]) * 2;
    
    % FOV四个角点方向（雷达坐标系：X右，Y前，Z上）
    corners_radar = zeros(4, 3);
    corners_radar(1, :) = angle_to_dir(az_min, el_max);  % 左上
    corners_radar(2, :) = angle_to_dir(az_max, el_max);  % 右上
    corners_radar(3, :) = angle_to_dir(az_max, el_min);  % 右下
    corners_radar(4, :) = angle_to_dir(az_min, el_min);  % 左下
    
    % 转换方向向量到地面坐标系
    cos_t = cos(tilt);
    sin_t = sin(tilt);
    corners_ground = zeros(4, 3);
    for i = 1:4
        x = corners_radar(i, 1);
        y = corners_radar(i, 2);
        z = corners_radar(i, 3);
        corners_ground(i, :) = [x, y*cos_t - z*sin_t, y*sin_t + z*cos_t];
    end
    
    % 计算FOV边界线与地面(z=0)或ROI边界的交点
    fov_color = [0.6, 0.3, 0.8];
    line_width = 1.0;
    
    % 绘制从雷达到FOV边界的四条射线
    for i = 1:4
        dir = corners_ground(i, :);
        % 计算与地面的交点
        if dir(3) < 0  % 指向地面
            t_ground = -radar_pos(3) / dir(3);
            end_pt = radar_pos + t_ground * dir;
        else
            % 用最大距离
            end_pt = radar_pos + max_range * dir;
        end
        
        % 限制在ROI范围内
        end_pt(1) = max(roi.x_range(1), min(roi.x_range(2), end_pt(1)));
        end_pt(2) = max(roi.y_range(1), min(roi.y_range(2), end_pt(2)));
        end_pt(3) = max(roi.z_range(1), min(roi.z_range(2), end_pt(3)));
        
        plot3([radar_pos(1), end_pt(1)], [radar_pos(2), end_pt(2)], [radar_pos(3), end_pt(3)], ...
              'Color', fov_color, 'LineWidth', line_width, 'LineStyle', '--', 'HandleVisibility', 'off');
    end
    
    % 绘制FOV在地面上的投影轮廓
    ground_pts = zeros(4, 3);
    for i = 1:4
        dir = corners_ground(i, :);
        if dir(3) < 0
            t_ground = -radar_pos(3) / dir(3);
            ground_pts(i, :) = radar_pos + t_ground * dir;
        else
            ground_pts(i, :) = radar_pos + max_range * dir;
            ground_pts(i, 3) = 0;
        end
    end
    
    % 连接地面投影点形成轮廓
    plot3([ground_pts(1,1), ground_pts(2,1)], [ground_pts(1,2), ground_pts(2,2)], [0, 0], ...
          'Color', fov_color, 'LineWidth', line_width, 'LineStyle', ':', 'HandleVisibility', 'off');
    plot3([ground_pts(3,1), ground_pts(4,1)], [ground_pts(3,2), ground_pts(4,2)], [0, 0], ...
          'Color', fov_color, 'LineWidth', line_width, 'LineStyle', ':', 'HandleVisibility', 'off');
    plot3([ground_pts(4,1), ground_pts(1,1)], [ground_pts(4,2), ground_pts(1,2)], [0, 0], ...
          'Color', fov_color, 'LineWidth', line_width, 'LineStyle', ':', 'HandleVisibility', 'off');
    plot3([ground_pts(2,1), ground_pts(3,1)], [ground_pts(2,2), ground_pts(3,2)], [0, 0], ...
          'Color', fov_color, 'LineWidth', line_width, 'LineStyle', ':', 'HandleVisibility', 'off');
    
    % 标记雷达位置
    scatter3(radar_pos(1), radar_pos(2), radar_pos(3), 80, 'k', '^', 'filled', 'DisplayName', 'Radar');
end

function dir = angle_to_dir(azimuth, elevation)
%ANGLE_TO_DIR 将方位角和俯仰角转换为单位方向向量。
%
% 雷达坐标系：X右，Y前，Z上
% azimuth: 方位角，正值向右
% elevation: 俯仰角，正值向上

    dir = [sin(azimuth) * cos(elevation), ...
           cos(azimuth) * cos(elevation), ...
           sin(elevation)];
end
