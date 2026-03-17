# Lab02 ISP Pipeline (16x16 RAW Bayer)

This project implements a fully pipelined ISP in Verilog (`ISP.v`) for a 16x16 Bayer RAW input stream.
The design targets fixed-latency streaming output and includes lens shading correction, dead-pixel correction, demosaicing, and color correction.

## 1) Problem Setup

- **Input stream**: 12-bit Bayer RAW pixels, raster order, frame size 16x16.
- **Parameter stream**: gain mesh coefficients loaded through `param_valid` / `param_gain` into `gain_buf`.
- **Output stream**: 12-bit RGB (`r_out`, `g_out`, `b_out`) with `out_valid`.
- **Clocking model**: one pixel per cycle when `in_valid=1`.
- **Top module**: `ISP`.

## 2) Spec-Oriented Design Targets

The implementation is structured around these practical spec goals:

- Correct Bayer-domain preprocessing before RGB reconstruction.
- Edge-safe neighborhood processing for both 5x5 (DPC) and 3x3 (demosaic) windows.
- Deterministic pipeline alignment with fixed end-to-end latency.
- Streaming interface behavior (`in_valid`/`out_valid`) with no frame-level stalls.
- Saturation-safe arithmetic for 12-bit output range `[0, 4095]`.

### Key Latency Constants

Defined at the top of `ISP.v`:

- `TARGET_LATENCY = 256`
- `PRE_STAGES = 3`
- `MID_STAGES = 3`
- `POST_STAGES = 2`
- `DEMOS_CENTER_IDX = 17`
- `DPC_CENTER_IDX = 230` (derived)

Flow-control taps used to align coordinate counters with window centers:

- `DPC_VALID_TAP_IDX = PRE_STAGES + DPC_CENTER_IDX`
- `DEMOS_VALID_TAP_IDX = DPC_VALID_TAP_IDX + 1 + MID_STAGES + DEMOS_CENTER_IDX`

## 3) Solution Architecture

### 3.1 Front-End / LSC Path

1. **Stage 1: BLC**
   - Black-level correction using parity (`x_odd`, `y_odd`) to select channel-dependent offset.
2. **Stage 2: LSC interpolation prep**
   - `LSC_weight_calc` computes `(i, d)` weights for x/y.
   - Selects 4 neighboring gain nodes (`g00`, `g01`, `g10`, `g11`) from `gain_buf`.
3. **Stage 3: Gain interpolation and pixel gain**
   - Bilinear interpolation computes `G_xy`.
4. **Stage 4: Apply gain to pixel**
   - `Pprime_xy = clip((P_xy * G_xy) >> 10)`.

### 3.2 DPC Path (5x5 Window)

5. **Stage 5: DPC window construction**
   - Shift-register buffer (`pixel_buf`) creates random-access 5x5 neighborhood.
   - Reflect padding handles borders.
6. **Stage 6 (MID 1): Directional sample extraction**
   - Extract 4 samples each for H/V/D1/D2 plus center.
   - Compute directional medians (`MedianOf4`).
7. **Stage 7 (MID 2): SAD scoring**
   - Compute directional SAD vs median for H/V/D1/D2.
8. **Stage 8 (MID 3): Direction select + replacement**
   - Choose direction with minimum SAD.
   - Replace center when `|center - target| > 320`.

### 3.3 Demosaic + CCM Path

9. **Stage 8 (post-DPC stream): Demosaicing**
   - `demos_buf` builds 3x3 neighborhood with reflect padding.
   - `DemosMod` reconstructs RGB according to Bayer parity.
10. **Stage 9: CCM (pipelined shift-add multiplier)**
   - Matrix form equivalent to:
     - `R' = (1100R - 50G - 50B + 512) >> 10`
     - `G' = (-50R + 1100G - 50B + 512) >> 10`
     - `B' = (-50R - 50G + 1100B + 512) >> 10`
   - Final clip to `[0, 4095]`.

## 4) Control/Alignment Strategy

- `out_valid_chain` delays `in_valid` by `TARGET_LATENCY` cycles.
- DPC and demosaic coordinate counters are triggered by dedicated tap indices so the local `(x,y)` always matches the center pixel in each windowed stage.
- Output masking and `out_valid` assertion are aligned with final pipeline registers.

## 5) What Is Distinctive in This Solution

- Explicit latency budgeting with compile-time constants.
- Window-center alignment derived analytically, then enforced by valid taps.
- Border-safe reflect padding in both DPC and demosaic stages.
- Area-aware median-of-4 building block for directional DPC.
- Shift-add based CCM implementation (no generic multipliers required for fixed coefficients).

## 6) Report Template Slots

### 6.1 Specification Mapping

- **Spec item 1**: _[describe requirement]_
- **Implementation hook**: _[module/signal/stage]_
- **Evidence**: _[waveform/sim log/code snippet]_

### 6.2 Pipeline & Latency Table

| Stage | Function | Registers Added | Running Latency |
|---|---|---:|---:|
| Stage 1 | _[BLC]_ | _[ ]_ | _[ ]_ |
| Stage 2 | _[LSC prep]_ | _[ ]_ | _[ ]_ |
| Stage 3 | _[Gain interp]_ | _[ ]_ | _[ ]_ |
| Stage 4 | _[Gain apply]_ | _[ ]_ | _[ ]_ |
| Stage 5-8 | _[DPC path]_ | _[ ]_ | _[ ]_ |
| Stage 8-9 | _[Demos + CCM]_ | _[ ]_ | _[ ]_ |

### 6.3 Verification Setup

- **Simulator/tool version**: _[ ]_
- **Testbench file**: _[ ]_
- **Input pattern(s)**: _[ ]_
- **Golden/check method**: _[ ]_

### 6.4 Functional Results

- **Case A (normal frame)**: _[pass/fail + notes]_
- **Case B (border behavior)**: _[pass/fail + notes]_
- **Case C (dead pixel correction)**: _[pass/fail + notes]_
- **Case D (latency check)**: _[expected vs measured]_

### 6.5 Waveform Evidence

- **Required signals**: `in_valid`, `out_valid`, `count`, `dpc_win_x/y`, `demos_win_x/y`, `r_out/g_out/b_out`
- **Screenshot 1**: _[insert image/link]_
- **Screenshot 2**: _[insert image/link]_
- **Key observation**: _[timing alignment / boundary handling / correction behavior]_

### 6.6 Synthesis / Implementation Results

- **Target library/FPGA**: _[ ]_
- **Clock constraint**: _[ ]_
- **Area / LUT / FF**: _[ ]_
- **Critical path / WNS**: _[ ]_
- **Power (if required)**: _[ ]_

### 6.7 Discussion

- **Trade-offs made**: _[area vs timing vs quality]_
- **Known limitations**: _[ ]_
- **Potential improvements**: _[ ]_

### 6.8 Conclusion

- _[1–3 bullets summarizing what was achieved and validated]_


