function [x, y, z, xyz_points] = sph2cart_points(range_m, azimuth_deg, elevation_deg)
%SPH2CART_POINTS 将 range / azimuth / elevation 转成雷达坐标系下的 x,y,z。
%
% 函数签名：
%   [x, y, z, xyz_points] = sph2cart_points(range_m, azimuth_deg, elevation_deg)
%
% 输入：
%   range_m       : double / 向量
%       距离，单位 m。
%   azimuth_deg   : double / 向量
%       方位角，单位度。正角表示向雷达右侧。
%   elevation_deg : double / 向量
%       俯仰角，单位度。正角表示向上。
%
% 输出：
%   x, y, z  : double / 向量
%       雷达坐标系下的三维坐标，单位 m。
%   xyz_points : double
%       维度 [N, 3]，每行为 [x, y, z]。
%
% 坐标系定义：
%   x : 水平横向
%   y : 雷达正前方
%   z : 竖直向上

    range_m = double(range_m(:));
    az_rad = deg2rad(double(azimuth_deg(:)));
    el_rad = deg2rad(double(elevation_deg(:)));

    x = range_m .* cos(el_rad) .* sin(az_rad);
    y = range_m .* cos(el_rad) .* cos(az_rad);
    z = range_m .* sin(el_rad);

    xyz_points = [x, y, z];
end
