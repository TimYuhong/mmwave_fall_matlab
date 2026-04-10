function points_world = transform_radar_to_world(points_radar, mount_cfg)
%TRANSFORM_RADAR_TO_WORLD Transform radar-local XYZ to ground-aligned frame.
%   points_world = transform_radar_to_world(points_radar, mount_cfg)
%
%   Input:
%     points_radar : double
%       Size [N, 3], columns are [x, y, z] in radar-local coordinates
%     mount_cfg    : struct
%       mount_cfg.height_m
%       mount_cfg.pitch_down_deg
%       optional: mount_cfg.position_world_m
%
%   Output:
%     points_world : double
%       Size [N, 3], columns are [x, y, z] in a ground-aligned frame
%
%   Convention:
%     1. World z points upward.
%     2. World origin defaults to the radar floor projection.
%     3. Positive pitch_down_deg means the radar boresight tilts toward ground.

    narginchk(2, 2);

    if size(points_radar, 2) ~= 3
        error('transform_radar_to_world:InvalidInputSize', ...
            'points_radar must have size [N, 3].');
    end

    if ~isstruct(mount_cfg)
        error('transform_radar_to_world:InvalidMountCfg', ...
            'mount_cfg must be a struct.');
    end

    if ~isfield(mount_cfg, 'pitch_down_deg')
        error('transform_radar_to_world:MissingField', ...
            'mount_cfg.pitch_down_deg is required.');
    end

    pitch_rad = deg2rad(double(mount_cfg.pitch_down_deg));
    rotation_radar_to_world = [ ...
        1, 0, 0; ...
        0, cos(pitch_rad), sin(pitch_rad); ...
        0, -sin(pitch_rad), cos(pitch_rad)];

    if isfield(mount_cfg, 'position_world_m') && ~isempty(mount_cfg.position_world_m)
        translation_world = double(mount_cfg.position_world_m(:)).';
    elseif isfield(mount_cfg, 'height_m')
        translation_world = [0, 0, double(mount_cfg.height_m)];
    else
        error('transform_radar_to_world:MissingField', ...
            'mount_cfg.position_world_m or mount_cfg.height_m is required.');
    end

    if numel(translation_world) ~= 3
        error('transform_radar_to_world:InvalidTranslation', ...
            'mount_cfg.position_world_m must have 3 elements.');
    end

    points_world = points_radar * rotation_radar_to_world.' + ...
        repmat(translation_world, size(points_radar, 1), 1);
end
