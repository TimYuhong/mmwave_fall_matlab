function points_xyz = radar_spherical_to_cartesian(range_m, az_deg, el_deg)
%RADAR_SPHERICAL_TO_CARTESIAN Convert radar spherical coordinates to XYZ.
%   points_xyz = radar_spherical_to_cartesian(range_m, az_deg, el_deg)
%
%   Input:
%     range_m : scalar or vector
%     az_deg  : scalar or vector
%     el_deg  : scalar or vector
%
%   Output:
%     points_xyz : double
%       Size [N, 3], columns are [x, y, z]
%
%   Coordinate convention:
%     x : horizontal azimuth axis
%     y : radar boresight / forward axis
%     z : elevation axis

    narginchk(3, 3);

    [range_m, az_deg, el_deg] = local_expand_inputs(range_m, az_deg, el_deg);

    az_rad = deg2rad(az_deg);
    el_rad = deg2rad(el_deg);

    x = range_m .* sin(az_rad) .* cos(el_rad);
    y = range_m .* cos(az_rad) .* cos(el_rad);
    z = range_m .* sin(el_rad);

    points_xyz = [x, y, z];
end

function [range_m, az_deg, el_deg] = local_expand_inputs(range_m, az_deg, el_deg)
    range_m = double(range_m(:));
    az_deg = double(az_deg(:));
    el_deg = double(el_deg(:));

    num_points = max([numel(range_m), numel(az_deg), numel(el_deg)]);

    if ~ismember(numel(range_m), [1, num_points]) || ...
            ~ismember(numel(az_deg), [1, num_points]) || ...
            ~ismember(numel(el_deg), [1, num_points])
        error('radar_spherical_to_cartesian:InputSizeMismatch', ...
            'range_m, az_deg and el_deg must be scalar or have the same length.');
    end

    if numel(range_m) == 1
        range_m = repmat(range_m, num_points, 1);
    end
    if numel(az_deg) == 1
        az_deg = repmat(az_deg, num_points, 1);
    end
    if numel(el_deg) == 1
        el_deg = repmat(el_deg, num_points, 1);
    end
end
