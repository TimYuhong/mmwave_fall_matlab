# mmwave_fall_matlab

This project now keeps only the front-end processing chain up to 2D FFT:

`ADC read -> frame reshape -> TDM-MIMO deinterleave -> Range FFT -> static clutter removal -> Doppler FFT`

All logic after 2D FFT has been removed, including:

- CFAR
- AoA / range-angle maps
- point cloud generation
- clustering / tracking / stable voxel accumulation
- point-cloud-related visualization

## Directory Layout

```text
mmwave_fall_matlab/
|-- main_demo.m
|-- main_visual_demo.m
|-- README.md
|-- config/
|   |-- Radar.cfg
|   |-- radar_config.m
|   `-- visual_config.m
|-- io/
|   |-- parse_ti_cfg.m
|   |-- read_dca1000_adc.m
|   `-- reshape_frame_cube.m
|-- array/
|   `-- deinterleave_tdm_mimo.m
|-- dsp/
|   |-- range_fft.m
|   |-- static_clutter_remove.m
|   `-- doppler_fft.m
|-- utils/
|   |-- range_bin_to_meters.m
|   `-- doppler_bin_to_mps.m
|-- vis/
|   |-- compute_visual_products.m
|   |-- show_rd_map.m
|   `-- show_micro_doppler_map.m
`-- results/
```

## Entry Points

`main_demo.m`

- reads one `.bin` file or a directory of `.bin` files
- processes every frame up to `rd_cube`
- returns intermediate results for each frame:
  `adc_frame_cube`, `mimo_cube`, `range_cube`, `clutter_free_cube`, `rd_cube`, `rd_power_map`, `rd_amplitude_map`

`main_visual_demo.m`

- supports a single `.bin` file
- generates and optionally saves:
  - RD map
  - micro-Doppler map

## Quick Start

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
results = main_demo('F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin');
```

Inspect one frame:

```matlab
r = results.file_results(1);
f = r.frames(50);

size(f.adc_frame_cube)
size(f.range_cube)
size(f.clutter_free_cube)
size(f.rd_cube)
```

Visualize RD and micro-Doppler:

```matlab
addpath(genpath('F:\2026\fall_project\mmwave_fall_matlab'));
visual_results = main_visual_demo('F:\Data_bin\parlor\fall\fall_S01_parlor_34_Raw_0.bin');
```

## Outputs

`results.file_results(k)`

- `file_path`
- `file_name`
- `num_frames`
- `num_adc_complex_samples`
- `adc_stream`
- `range_axis_m`
- `doppler_axis_mps`
- `frames`

`results.file_results(k).frames(frame_idx)`

- `frame_id`
- `adc_frame_cube`
- `mimo_cube`
- `range_cube`
- `clutter_free_cube`
- `rd_cube`
- `rd_power_map`
- `rd_amplitude_map`
