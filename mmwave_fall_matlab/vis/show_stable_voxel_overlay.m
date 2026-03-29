function fig = show_stable_voxel_overlay(current_cloud, stable_cloud, fig_title)
%SHOW_STABLE_VOXEL_OVERLAY 将当前帧点云与稳定体素画在一起。
% 函数签名：
%   fig = show_stable_voxel_overlay(current_cloud, stable_cloud, fig_title)
%
% 输入：
%   current_cloud : struct
%       当前帧点云，至少包含 xyz。
%   stable_cloud : struct
%       build_voxel_confidence_map.m 输出的 stable_cloud。
%   fig_title : char/string，可选
%       图标题。

    if nargin < 3 || isempty(fig_title)
        fig_title = 'Current Cloud and Stable Voxels';
    end

    fig = figure('Name', 'Stable Voxel Overlay', 'Color', 'w');
    hold on;

    if isstruct(current_cloud) && isfield(current_cloud, 'xyz') && ~isempty(current_cloud.xyz)
        scatter3(current_cloud.xyz(:, 1), current_cloud.xyz(:, 2), current_cloud.xyz(:, 3), ...
            18, [0.25, 0.55, 0.95], 'filled', 'DisplayName', 'Current Frame');
    end

    if isstruct(stable_cloud) && isfield(stable_cloud, 'xyz') && ~isempty(stable_cloud.xyz)
        scatter3(stable_cloud.xyz(:, 1), stable_cloud.xyz(:, 2), stable_cloud.xyz(:, 3), ...
            52, [0.95, 0.25, 0.15], 's', 'filled', 'DisplayName', 'Stable Voxels');
    end

    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    title(fig_title, 'Interpreter', 'none');
    grid on;
    axis equal;
    view(35, 20);
    legend('Location', 'best');
    hold off;
end
