function [azimuth_spectrum, elevation_spectrum, peak_info, spectrum_2d] = capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg)
%CAPON_AOA 使用 Capon/MVDR 估计方位角、俯仰角谱和峰值位置。
%
% 函数签名：
%   [azimuth_spectrum, elevation_spectrum, peak_info, spectrum_2d] = ...
%       capon_aoa(snapshot_matrix, antenna_layout, aoa_cfg)
%
% 输入：
%   snapshot_matrix : complex double
%       维度 [num_virtual_ant, num_snapshots]
%       如果只有一个检测快拍，也允许输入 [num_virtual_ant, 1]。
%
%   antenna_layout : struct
%       至少包含：
%       antenna_layout.lambda_m
%       antenna_layout.virtual_pos_m   [num_virtual_ant, 2]，列为 [x, z]
%
%   aoa_cfg : struct
%       aoa_cfg.azimuth_scan_deg   : 方位角扫描网格（度）
%       aoa_cfg.elevation_scan_deg : 俯仰角扫描网格（度）
%       aoa_cfg.diagonal_loading   : 对角加载系数
%       aoa_cfg.remove_mean        : 是否按快拍维去均值
%
% 输出：
%   azimuth_spectrum : struct
%       .angle_deg    : 方位角网格
%       .power_linear : 方位角谱（对俯仰维做 max 投影）
%       .power_db     : 归一化 dB 谱
%
%   elevation_spectrum : struct
%       .angle_deg    : 俯仰角网格
%       .power_linear : 俯仰角谱（对方位维做 max 投影）
%       .power_db     : 归一化 dB 谱
%
%   peak_info : struct
%       .azimuth_deg
%       .elevation_deg
%       .azimuth_index
%       .elevation_index
%       .peak_linear
%       .peak_db
%
%   spectrum_2d : double
%       维度 [num_elevation_grid, num_azimuth_grid] 的 2D Capon 谱。
%
% 简化假设：
%   1. 使用窄带远场模型。
%   2. 如果只输入单快拍，则通过对角加载保证协方差矩阵可逆。
%   3. 默认只取单目标主峰。

    narginchk(3, 3);

    if isvector(snapshot_matrix)
        snapshot_matrix = snapshot_matrix(:);
    end

    if aoa_cfg.remove_mean
        snapshot_matrix = snapshot_matrix - mean(snapshot_matrix, 2);
    end

    num_ant = size(snapshot_matrix, 1);
    num_snapshots = size(snapshot_matrix, 2);

    if size(antenna_layout.virtual_pos_m, 1) ~= num_ant
        error('capon_aoa:SizeMismatch', ...
            '快拍通道数与虚拟阵元数不一致。');
    end

    covariance = (snapshot_matrix * snapshot_matrix') / max(num_snapshots, 1);
    covariance = 0.5 * (covariance + covariance');

    loading = aoa_cfg.diagonal_loading * trace(covariance) / max(num_ant, 1);
    covariance = covariance + loading * eye(num_ant);
    covariance_inv = pinv(covariance);

    az_grid = aoa_cfg.azimuth_scan_deg(:).';
    el_grid = aoa_cfg.elevation_scan_deg(:).';
    spectrum_2d = zeros(numel(el_grid), numel(az_grid));

    for el_idx = 1:numel(el_grid)
        el_rad = deg2rad(el_grid(el_idx));
        sin_el = sin(el_rad);
        cos_el = cos(el_rad);

        for az_idx = 1:numel(az_grid)
            az_rad = deg2rad(az_grid(az_idx));
            ux = sin(az_rad) * cos_el;
            uz = sin_el;

            phase = 2 * pi / antenna_layout.lambda_m * ...
                (antenna_layout.virtual_pos_m(:, 1) * ux + ...
                 antenna_layout.virtual_pos_m(:, 2) * uz);

            steering = exp(1j * phase);
            denom = real(steering' * covariance_inv * steering);
            spectrum_2d(el_idx, az_idx) = 1 / max(denom, eps);
        end
    end

    az_power = max(spectrum_2d, [], 1).';
    el_power = max(spectrum_2d, [], 2);

    [peak_linear, linear_idx] = max(spectrum_2d(:));
    [peak_el_idx, peak_az_idx] = ind2sub(size(spectrum_2d), linear_idx);

    azimuth_spectrum = struct();
    azimuth_spectrum.angle_deg = az_grid(:);
    azimuth_spectrum.power_linear = az_power;
    azimuth_spectrum.power_db = 10 * log10(az_power / max(peak_linear, eps));

    elevation_spectrum = struct();
    elevation_spectrum.angle_deg = el_grid(:);
    elevation_spectrum.power_linear = el_power;
    elevation_spectrum.power_db = 10 * log10(el_power / max(peak_linear, eps));

    peak_info = struct();
    peak_info.azimuth_deg = az_grid(peak_az_idx);
    peak_info.elevation_deg = el_grid(peak_el_idx);
    peak_info.azimuth_index = peak_az_idx;
    peak_info.elevation_index = peak_el_idx;
    peak_info.peak_linear = peak_linear;
    peak_info.peak_db = 0;
end
