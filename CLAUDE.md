# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Vivado FPGA project targeting the Arty A7 development board. The project implements a Vending Machine controller with VGA display interface. Users can navigate through a 3x3 grid of products, select quantities, and manage a shopping cart using physical buttons on the FPGA board.

## Project Structure

```
lab10/
├── lab10.xpr                    # Vivado project file
├── lab10.srcs/
│   ├── sources_1/
│   │   ├── lab10.v              # Top-level module (vending machine controller)
│   │   ├── vga_sync.v           # VGA sync signal generator (640x480 @ 60Hz)
│   │   ├── clk_divider.v        # Clock divider module
│   │   ├── sram.v               # Initialized SRAM block for images
│   │   ├── debounce.v           # Button debouncing module
│   │   ├── vending_fsm.v        # Product selection FSM
│   │   ├── VendingMachineBg.mem # Background image (40x70 pixels)
│   │   └── SelectBox.mem        # Selection box sprite (25x5 pixels)
│   └── constrs_1/
│       └── lab10.xdc            # Pin constraints for Arty A7 board
```

## Hardware Architecture

### Top Module (lab10.v)
- **Target Board**: Arty A7 (Artix-7 FPGA)
- **Input Clock**: 100 MHz system clock
- **VGA Output**: 640x480 @ 60Hz (requires 25 MHz pixel clock)
- **Display Buffer**: 40x70 pixels scaled 6x to 240x420 (centered on screen)
- **Image Storage**: SRAM initialized with background and selection box sprite
- **User Interface**: 3x3 product grid with stock/cart visualization
- **Button Inputs**: 4 debounced buttons for navigation and selection

### Key Components

1. **VGA Sync Generator** (vga_sync.v)
   - Generates HSYNC/VSYNC signals for 640x480 @ 60Hz
   - Provides pixel coordinates (pixel_x, pixel_y)
   - Generates 25 MHz pixel tick from 50 MHz clock

2. **Clock Divider** (clk_divider.v)
   - Parameterized clock divider (divides by 2 for VGA: 100MHz → 50MHz)

3. **SRAM Modules** (sram.v)
   - **Background SRAM**: 40×70 pixels (2,800 words) - VendingMachineBg.mem
   - **Sprite SRAM**: 25×5 pixels (125 words) - SelectBox.mem
   - 12-bit color depth (4 bits per RGB channel)
   - Transparent color support: 12'h0F0 (green screen)

4. **Debounce Module** (debounce.v)
   - Parameterized debouncing (default: 10ms at 100 MHz)
   - 2-stage synchronizer for metastability prevention
   - Counter-based stable input detection

5. **Vending FSM** (vending_fsm.v)
   - Manages product selection index (0-8)
   - Edge-triggered navigation (left/right buttons)
   - Circular wrapping at boundaries

### User Interaction Mechanism

**Button Mapping:**
- **usr_btn[0]**: Navigate right (increment selection_index)
- **usr_btn[1]**: Navigate left (decrement selection_index)
- **usr_btn[2]**: Add to cart / cycle quantity (0 → stock max → 0)
- **usr_btn[3]**: Submit order (TODO: not yet implemented)

**Product Grid Layout (3x3):**
```
Row 1: Index 0, 1, 2 (base_y = 14)
Row 2: Index 3, 4, 5 (base_y = 26)
Row 3: Index 6, 7, 8 (base_y = 37)
```

**Visual Feedback:**
- **Selection Box**: 25×5 sprite scaled 2x, positioned over selected item
- **Stock Indicators**: 5 dots per item (8×8 pixels each)
  - Gray: Out of stock
  - Blue: In stock
  - Green: Added to cart
- **Display Layers** (back to front):
  1. Black borders
  2. Background image (40×70, scaled 6x)
  3. Stock/cart dots
  4. Selection box sprite (with transparency)

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

The SRAM modules read initial values using `$readmemh()`:

**VendingMachineBg.mem:**
- 2,800 words (40 × 70 pixels)
- 12-bit hex RGB values
- Contains product display background

**SelectBox.mem:**
- 125 words (25 × 5 pixels)
- 12-bit hex RGB values
- Green screen color (12'h0F0) used for transparency

## Modification Guidelines

When modifying the design:

1. **Changing Background Resolution**: Update VBUF_W and VBUF_H parameters in lab10.v, adjust SCALE_FACTOR for desired screen coverage
2. **Modifying Product Layout**: Update base coordinates in the case statement (lines 225-239) and corresponding constants (lines 286-294)
3. **Adding More Products**: Extend grid beyond 3×3 by:
   - Increasing selection_index width in vending_fsm.v
   - Adding new case entries for coordinates
   - Expanding stock and cart_quantity arrays
   - Adding new `DOT_LOGIC` macro invocations
4. **Changing Initial Stock**: Modify initial block for stock array (lines 82-92)
5. **Adjusting Debounce Time**: Change DELAY_TIME parameter in debounce module instantiation
6. **Implementing Order Submission**: Complete TODO at line 110 for btn3_posedge logic

## SRAM Synthesis Note

The design uses a registered write enable signal (`sram_we_reg`) that is always kept low. This prevents accidental writes while ensuring proper BRAM inference by Vivado. The `(* ram_style = "block" *)` attribute in sram.v forces Block RAM inference instead of distributed RAM.

## Scaling and Coordinate System

**Background Scaling:**
- Source: 40×70 pixels
- Scaled: 6× → 240×420 pixels
- Position: Centered on 640×480 screen (H_START=200, V_START=30)

**Selection Box Scaling:**
- Source: 25×5 pixels
- Scaled: 2× → 50×10 pixels
- Position: Dynamically calculated based on selection_index

**Coordinate Mapping:**
- Background coordinates (40×70 grid) → Screen coordinates (640×480)
- Formula: `screen_pos = H_START/V_START + grid_pos × SCALE_FACTOR`

## Current Stock Configuration

Default stock levels (can be modified in lab10.v lines 82-92):
```
Index 0: 5 items    Index 1: 0 items    Index 2: 0 items
Index 3: 5 items    Index 4: 5 items    Index 5: 0 items
Index 6: 0 items    Index 7: 0 items    Index 8: 5 items
```
