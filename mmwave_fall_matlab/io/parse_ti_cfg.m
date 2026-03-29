function raw = parse_ti_cfg(cfg_path)
%PARSE_TI_CFG 解析 TI Radar.cfg 中与离线处理相关的关键参数。
%
% 输入：
%   cfg_path : char/string
%       TI 配置文件路径。
%
% 输出：
%   raw : struct
%       raw.channel.num_rx
%       raw.channel.num_tx
%       raw.profile.*
%       raw.frame.*

    file_text = fileread(cfg_path);
    lines = string(regexp(file_text, '\r\n|\n|\r', 'split'));
    lines = strtrim(lines);
    lines = lines(lines ~= "");

    raw = struct();
    raw.channel = struct();
    raw.profile = struct();
    raw.frame = struct();
    raw.adcbuf = struct('sample_swap', 1, 'channel_interleave', 1);

    chirp_table = [];

    for idx = 1:numel(lines)
        line = lines(idx);
        if startsWith(line, "%") || startsWith(line, "#")
            continue;
        end

        tokens = split(line);
        cmd = tokens(1);

        switch cmd
            case "channelCfg"
                rx_mask = str2double(tokens(2));
                tx_mask = str2double(tokens(3));
                raw.channel.rx_mask = rx_mask;
                raw.channel.tx_mask = tx_mask;
                raw.channel.num_rx = count_bits(rx_mask);
                raw.channel.num_tx = count_bits(tx_mask);

            case "profileCfg"
                raw.profile.profile_id = str2double(tokens(2));
                raw.profile.start_freq_ghz = str2double(tokens(3));
                raw.profile.idle_time_us = str2double(tokens(4));
                raw.profile.adc_start_time_us = str2double(tokens(5));
                raw.profile.ramp_end_time_us = str2double(tokens(6));
                raw.profile.freq_slope_mhz_us = str2double(tokens(9));
                raw.profile.num_adc_samples = str2double(tokens(11));
                raw.profile.dig_out_sample_rate_ksps = str2double(tokens(12));

            case "chirpCfg"
                row = struct();
                row.start_idx = str2double(tokens(2));
                row.end_idx = str2double(tokens(3));
                row.profile_id = str2double(tokens(4));
                row.tx_mask = str2double(tokens(9));
                chirp_table = [chirp_table; row]; %#ok<AGROW>

            case "frameCfg"
                raw.frame.chirp_start_idx = str2double(tokens(2));
                raw.frame.chirp_end_idx = str2double(tokens(3));
                raw.frame.num_loops = str2double(tokens(4));
                raw.frame.num_frames = str2double(tokens(5));
                raw.frame.frame_periodicity_ms = str2double(tokens(6));

            case "adcbufCfg"
                if numel(tokens) >= 5
                    raw.adcbuf.sample_swap = str2double(tokens(4));
                    raw.adcbuf.channel_interleave = str2double(tokens(5));
                end
        end
    end

    raw.frame.num_unique_chirps = raw.frame.chirp_end_idx - raw.frame.chirp_start_idx + 1;
    raw.frame.actual_tx_order = build_tx_order(chirp_table, raw.frame);
end

function num_bits = count_bits(mask_value)
    num_bits = 0;
    while mask_value > 0
        num_bits = num_bits + bitand(mask_value, 1);
        mask_value = bitshift(mask_value, -1);
    end
end

function tx_order = build_tx_order(chirp_table, frame_cfg)
    chirp_ids = frame_cfg.chirp_start_idx:frame_cfg.chirp_end_idx;
    tx_order = zeros(1, numel(chirp_ids));

    for chirp_id = chirp_ids
        matched = false;
        for row_idx = 1:numel(chirp_table)
            row = chirp_table(row_idx);
            if chirp_id >= row.start_idx && chirp_id <= row.end_idx
                tx_order(chirp_id - frame_cfg.chirp_start_idx + 1) = tx_mask_to_id(row.tx_mask);
                matched = true;
                break;
            end
        end

        if ~matched
            error('parse_ti_cfg:MissingChirpCfg', ...
                'chirpCfg 中未找到 chirp %d 的发射天线定义。', chirp_id);
        end
    end
end

function tx_id = tx_mask_to_id(tx_mask)
    switch tx_mask
        case 1
            tx_id = 1;
        case 2
            tx_id = 2;
        case 4
            tx_id = 3;
        otherwise
            error('parse_ti_cfg:UnsupportedTxMask', ...
                '当前仅支持单 TX mask，收到 tx_mask=%d。', tx_mask);
    end
end
