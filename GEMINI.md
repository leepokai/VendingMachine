# Gemini Context: Verilog Vending Machine

## Project Overview

This is a hardware design project implementing a graphical Vending Machine on a Xilinx Artix-7 FPGA (Digilent Arty A7). The system features a 640x480 VGA interface to display a rich graphical user interface with sprite-based animations.

The vending machine allows users to:
1.  **Select Drinks**: Navigate a 3x3 grid of beverages (Water, Juice, Tea, Cola, etc.) and adjust quantities ("shopping cart").
2.  **Make Payments**: Insert coins ($1, $5, $10) to cover the total cost.
3.  **Receive Change**: An intelligent dispenser algorithm calculates and dispenses the optimal change.
4.  **View Animations**: Watch visual feedback where purchased items "drop" sequentially into the collection bin.

## Key Features & Architecture

### 1. Finite State Machines (FSMs)
The system logic is distributed across several specialized FSMs:
*   **`main_fsm`**: Orchestrates the high-level system state, transitioning between `SELECTION` and `PAYMENT` modes.
*   **`vending_fsm`**: Handles navigation (Left/Right) and selection index updates within the 3x3 grid during the `SELECTION` phase.
*   **`coin_selector`**: Manages coin denomination selection ($1, $5, $10) via Up/Down buttons during the `PAYMENT` phase.
*   **`change_dispenser`**: A greedy algorithm that calculates the minimum number of coins needed for change.
*   **`animation_controller`**: A complex state machine that manages the **sequential** playback of drop animations. It iterates through the user's cart and plays the specific animation for every single item purchased.

### 2. Graphical Rendering Engine
The VGA controller (`vga_sync`) drives a 640x480 display. The rendering logic in `lab10.v` uses a strict **priority-based layering system** to compose the final image. 

**Rendering Layer Order (Highest to Lowest Priority):**
1.  **UI Text Overlays**: "TOTAL", "PAID", "CHANGE", and Coin Counts.
2.  **Selection Box**: The highlight frame around the currently selected drink.
3.  **Stock Indicators (Dots)**: 5 vertical dots indicating current stock/selection level. (Rendered *on top* of the chassis).
4.  **Vending Machine Chassis**: The main static background image (with a transparent window).
5.  **Item Drop Animation**: Dynamic sprite animations (Water, Juice, Tea, Cola) that appear "inside" the machine (behind the chassis window).
6.  **Green Background**: The furthest background layer visible through the machine's window.

### 3. Memory & Assets
On-chip SRAM is used to store graphical assets, loaded from `.mem` files:
*   **Backgrounds**: `VendingMachineBg.mem`, `VendingMachineGreenBgsBg.mem`.
*   **UI Elements**: `SelectBox.mem`.
*   **Coins**: `Coin1.mem`, `Coin5.mem`, `Coin10.mem`.
*   **Animations**: `WaterDropSheet.mem`, `JuiceDropSheet.mem`, `TeaDropSheet.mem`, `ColaDropSheet.mem`, `EnergyDropSheet.mem` (mapped generically).

## Input/Output Mapping

*   **clk**: 100 MHz system clock.
*   **reset_n**: Active-low reset.
*   **usr_btn[3:0]**:
    *   `btn3`: **Confirm/Switch Mode** (Submit Selection <-> Pay).
    *   `btn2`: **Action** (Add to Cart / Insert Coin).
    *   `btn1`: **Navigation** (Left / Coin Down).
    *   `btn0`: **Navigation** (Right / Coin Up).
*   **VGA**: Standard RGB444 output with HSYNC/VSYNC.

## Current Implementation Status

### Recent Updates
*   **Multi-Item Animation**: The `animation_controller` was rewritten to support multi-item purchases. It accepts a flattened cart array (`flat_cart_quantity`) and plays the drop animation $N$ times for $N$ items purchased, ensuring visual feedback matches the exact purchase list.
*   **Layering Fix**: The rendering logic was updated to ensure "Stock Dots" are drawn *on top* of the Vending Machine Chassis, while animations remain correctly "inside" (behind) the chassis.

### Build Instructions
The project is a standard Vivado project (`lab10.xpr`).

1.  **Synthesize & Implement**: Run the standard Vivado build flow.
2.  **Bitstream**: The target bitstream is generated in `lab10.runs/impl_1/`.
3.  **Programming**: Use the Hardware Manager to program the Arty A7 (`xc7a35t`).

## File Structure
*   `lab10/lab10.srcs/sources_1/`:
    *   `lab10.v`: Top-level module and rendering logic.
    *   `animation_controller.v`: Animation sequencing logic.
    *   `change_dispenser.v`: Change calculation logic.
    *   `main_fsm.v`, `vending_fsm.v`: State control.
    *   `sram.v`: Memory interface.
*   `backup_mem/`: Source directory for `.mem` initialization files.