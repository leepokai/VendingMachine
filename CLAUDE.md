# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Vivado FPGA project targeting the Arty A7 development board. The project implements a VGA display system that animates a fish swimming across a seabed background. Despite the repository name "VendingMachine", the current implementation (lab10) is a VGA animation demo.

## Project Structure

```
lab10/
├── lab10.xpr                    # Vivado project file
├── lab10.srcs/
│   ├── sources_1/
│   │   ├── lab10.v              # Top-level module
│   │   ├── vga_sync.v           # VGA sync signal generator (640x480 @ 60Hz)
│   │   ├── clk_divider.v        # Clock divider module
│   │   ├── sram.v               # Initialized SRAM block for images
│   │   └── images.mem           # Image data file (12-bit RGB values)
│   └── constrs_1/
│       └── lab10.xdc            # Pin constraints for Arty A7 board
```

## Hardware Architecture

### Top Module (lab10.v)
- **Target Board**: Arty A7 (Artix-7 FPGA)
- **Input Clock**: 100 MHz system clock
- **VGA Output**: 640x480 @ 60Hz (requires 25 MHz pixel clock)
- **Display Buffer**: 320x240 pixels scaled 2x to fill 640x480 screen
- **Image Storage**: SRAM initialized with background (320x240) and fish sprites (64x32 each)

### Key Components

1. **VGA Sync Generator** (vga_sync.v)
   - Generates HSYNC/VSYNC signals for 640x480 @ 60Hz
   - Provides pixel coordinates (pixel_x, pixel_y)
   - Generates 25 MHz pixel tick from 50 MHz clock

2. **Clock Divider** (clk_divider.v)
   - Parameterized clock divider (divides by 2 for VGA: 100MHz → 50MHz)

3. **SRAM Module** (sram.v)
   - Inferred Block RAM for image storage
   - Initialized from images.mem file
   - 12-bit color depth (4 bits per RGB channel)
   - Size: 320×240 background + 64×32×2 fish sprites = 80,896 words

### Animation Mechanism

- Fish animation uses a 32-bit counter (fish_clock)
- Upper 12 bits [31:20] control horizontal position
- Bit [23] alternates between two fish sprite frames
- Fish moves right at ~10.49 ms per pixel
- Automatically wraps when reaching screen edge

## Vivado Development Commands

### Opening the Project
```tcl
# Open in Vivado GUI
vivado lab10/lab10.xpr

# Or from TCL console
open_project lab10/lab10.xpr
```

### Synthesis and Implementation
```tcl
# Reset previous runs
reset_run synth_1
reset_run impl_1

# Run synthesis
launch_runs synth_1
wait_on_run synth_1

# Run implementation
launch_runs impl_1
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

### Programming the Board
```tcl
# Program FPGA (volatile)
open_hw_manager
connect_hw_server
open_hw_target
set_property PROGRAM.FILE {lab10/lab10.runs/impl_1/lab10.bit} [get_hw_devices xc7a35t_0]
program_hw_devices [get_hw_devices xc7a35t_0]
```

## Important Design Constraints

### Timing Constraints (lab10.xdc)
- System clock: 100 MHz (10 ns period)
- Clock input: Pin E3
- Reset: Pin C2 (active low)

### VGA Timing
- Horizontal: 640 visible + 48 front porch + 96 sync + 16 back porch = 800 total
- Vertical: 480 visible + 10 front porch + 2 sync + 33 back porch = 525 total
- Pixel clock: 25 MHz (generated from 50 MHz via mod-2 counter)

### Pin Assignments
- Buttons: usr_btn[3:0] on pins D9, C9, B9, B8
- LEDs: usr_led[3:0] on pins H5, J5, T9, T10
- VGA signals: HSYNC (M13), VSYNC (R10), RGB[11:0] (various pins)

## Memory Initialization

The SRAM module reads initial values from `images.mem` using `$readmemh()`. This file must contain:
- First 76,800 entries: 320×240 background image (12-bit hex values)
- Next 2,048 entries: First 64×32 fish sprite
- Next 2,048 entries: Second 64×32 fish sprite

Total: 80,896 memory words

## Modification Guidelines

When modifying the design:

1. **Changing Image Resolution**: Update VBUF_W and VBUF_H parameters, adjust SRAM size accordingly
2. **Adding More Sprites**: Extend fish_addr array and update SRAM RAM_SIZE parameter
3. **Adjusting Animation Speed**: Modify which bits of fish_clock are used for position (currently [31:20])
4. **Changing VGA Resolution**: Update vga_sync.v parameters and pixel scaling logic in lab10.v

## SRAM Synthesis Note

The design includes `assign sram_we = usr_btn[3]` as a workaround for a Vivado synthesis bug. Without connecting sram_we to an input, Vivado fails to infer the RAM as BRAM. The `(* ram_style = "block" *)` attribute in sram.v forces BRAM inference.
