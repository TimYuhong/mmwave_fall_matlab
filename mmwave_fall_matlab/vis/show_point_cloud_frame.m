function fig = show_point_cloud_frame(frame_result, frame_index, file_label)
%SHOW_POINT_CLOUD_FRAME 显示单帧点云、主人体簇和稳点点云。
%
% 输入：
%   frame_result : struct
%       main_demo.m 输出的单帧结果结构体。
%   frame_index  : 标量
%   file_label   : 图标题用文件名

    fig = figure('Name', sprintf('Point Cloud - Frame %d', frame_index), 'Color', 'w');
    hold on;

    if isfield(frame_result, 'point_cloud') && ~isempty(frame_result.point_cloud) ...
            && isfield(frame_result.point_cloud, 'xyz') && ~isempty(frame_result.point_cloud.xyz)
        scatter3(frame_result.point_cloud.xyz(:, 1), ...
                 frame_result.point_cloud.xyz(:, 2), ...
                 frame_result.point_cloud.xyz(:, 3), ...
                 28, [0.2, 0.55, 0.95], 'filled', 'DisplayName', 'All Detections');
    end

    if isfield(frame_result, 'human_cloud') && ~isempty(frame_result.human_cloud) ...
            && isfield(frame_result.human_cloud, 'xyz') && ~isempty(frame_result.human_cloud.xyz)
        scatter3(frame_result.human_cloud.xyz(:, 1), ...
                 frame_result.human_cloud.xyz(:, 2), ...
                 frame_result.human_cloud.xyz(:, 3), ...
                 36, [0.95, 0.35, 0.20], 'filled', 'DisplayName', 'Primary Human');
    end

    if isfield(frame_result, 'stable_cloud') && ~isempty(frame_result.stable_cloud) ...
            && isfield(frame_result.stable_cloud, 'xyz') && ~isempty(frame_result.stable_cloud.xyz)
        scatter3(frame_result.stable_cloud.xyz(:, 1), ...
                 frame_result.stable_cloud.xyz(:, 2), ...
                 frame_result.stable_cloud.xyz(:, 3), ...
                 42, [0.10, 0.70, 0.25], 'filled', 'DisplayName', 'Stable Cloud');
    end

    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    title(sprintf('Point Cloud | %s | Frame %d', file_label, frame_index), 'Interpreter', 'none');
    legend('Location', 'best');
    grid on;
    axis equal;
    view(35, 20);
    hold off;
end
