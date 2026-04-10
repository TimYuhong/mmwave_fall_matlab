function channel_response = extract_multichannel_rd_response(rd_cube, range_bin, doppler_bin)
%EXTRACT_MULTICHANNEL_RD_RESPONSE Extract one RD cell across all RX/TX.
%   channel_response = extract_multichannel_rd_response(rd_cube, range_bin, doppler_bin)
%
%   Input:
%     rd_cube      : complex double
%       Size [num_range_bins, num_doppler_bins, num_rx, num_tx]
%     range_bin    : scalar, 1-based range-bin index
%     doppler_bin  : scalar, 1-based Doppler-bin index
%
%   Output:
%     channel_response : complex double
%       Size [num_rx, num_tx]

    narginchk(3, 3);

    if ndims(rd_cube) ~= 4
        error('extract_multichannel_rd_response:InvalidCube', ...
            'rd_cube must be a 4-D array with size [range, doppler, rx, tx].');
    end

    if ~isscalar(range_bin) || ~isscalar(doppler_bin)
        error('extract_multichannel_rd_response:InvalidIndex', ...
            'range_bin and doppler_bin must be scalar indices.');
    end

    num_range_bins = size(rd_cube, 1);
    num_doppler_bins = size(rd_cube, 2);
    num_rx = size(rd_cube, 3);
    num_tx = size(rd_cube, 4);

    if range_bin < 1 || range_bin > num_range_bins || range_bin ~= floor(range_bin)
        error('extract_multichannel_rd_response:RangeBinOutOfBounds', ...
            'range_bin is out of bounds: %g', range_bin);
    end

    if doppler_bin < 1 || doppler_bin > num_doppler_bins || doppler_bin ~= floor(doppler_bin)
        error('extract_multichannel_rd_response:DopplerBinOutOfBounds', ...
            'doppler_bin is out of bounds: %g', doppler_bin);
    end

    channel_response = reshape( ...
        rd_cube(range_bin, doppler_bin, :, :), ...
        [num_rx, num_tx]);
end
