function [rd_power_map, rd_linear_map] = noncoherent_integration_rd(rd_cube)
%NONCOHERENT_INTEGRATION_RD Noncoherent integration on RD data.
%   [rd_power_map, rd_linear_map] = noncoherent_integration_rd(rd_cube)
%
%   Input:
%     rd_cube : numeric
%       1. [num_range_bins, num_doppler_bins, num_rx, num_tx] complex RD cube
%       2. [num_range_bins, num_doppler_bins] 2D RD map
%
%   Output:
%     rd_power_map : numeric
%       2D fused RD power map after noncoherent integration.
%     rd_linear_map : numeric
%       2D fused RD amplitude map, defined as sqrt(max(rd_power_map, 0)).
%
%   Notes:
%     1. This step is noncoherent integration (NCI): it sums channel power
%        |rd_cube|.^2 across RX/TX dimensions.
%     2. This is NOT coherent summation. Channel phase is not aligned or
%        accumulated here.
%     3. The downstream CFAR should run on the fused 2D amplitude map.
    narginchk(1, 1);

    if isempty(rd_cube)
        rd_power_map = zeros(0, 0);
        rd_linear_map = zeros(0, 0);
        return;
    end

    if ~isnumeric(rd_cube) || isvector(rd_cube)
        error('noncoherent_integration_rd:InvalidInput', ...
            'rd_cube must be a numeric 2D map or [range, doppler, rx, tx] array.');
    end

    data_size = size(rd_cube);
    num_range_bins = data_size(1);
    num_doppler_bins = data_size(2);

    if ismatrix(rd_cube)
        rd_power_map = abs(rd_cube).^2;
    else
        rd_power_cube = abs(rd_cube).^2;
        rd_power_cube = reshape(rd_power_cube, num_range_bins, num_doppler_bins, []);
        rd_power_map = sum(rd_power_cube, 3);
    end

    rd_linear_map = sqrt(max(rd_power_map, 0));
end
