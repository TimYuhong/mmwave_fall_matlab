function cfg = visual_config()
%VISUAL_CONFIG Visualization settings for RD and micro-Doppler only.

    cfg = struct();
    cfg.default_bin_path = 'F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin';
    cfg.range_roi_m = [0.30, 5.50];
    cfg.skip_near_range_bins = 6;
    cfg.colormap_name = 'parula';
    cfg.enable_normalization = true;
    cfg.normalization_method = 'max';
    cfg.preferred_frame_index = 82;
    cfg.save_figures = true;
    cfg.output_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
end
