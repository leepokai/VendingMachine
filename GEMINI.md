# Vending Machine FPGA Project

## 1. Project Overview
This project implements a fully functional Vending Machine controller on a Digilent Arty A7 FPGA board. It features a graphical user interface (GUI) displayed via VGA, allowing users to select drinks, adjust quantities, insert coins, and receive change.

### Key Features
- **VGA Display:** 640x480 resolution @ 60Hz.
- **Interactive UI:** Graphical selection of 9 different drinks with animations.
- **Payment System:** Accepts $1, $5, and $10 coins with change calculation.
- **State Machine Control:** Robust FSM managing Selection, Payment, and Dispensing states.
- **Hardware Integration:** Utilizes onboard buttons for input and LEDs for status.

## 2. Technical Stack
- **Language:** Verilog HDL
- **Toolchain:** Xilinx Vivado (Design Suite)
- **Target Hardware:** Digilent Arty A7 (Artix-7 FPGA)
- **Project File:** `lab10/lab10.xpr`
- **Top-Level Module:** `lab10` (in `lab10/lab10.srcs/sources_1/lab10.v`)
- **Constraints File:** `lab10/lab10.srcs/constrs_1/lab10.xdc`

## 3. Architecture

### Module Hierarchy
The design is hierarchical with `lab10` as the top-level module, interconnecting various controllers and drivers:

*   **`lab10` (Top):** Instantiates all submodules and handles global I/O (buttons, LEDs, VGA signals).
    *   **Control Logic:**
        *   `debounce`: Cleans button inputs.
        *   `main_fsm`: Manages the high-level state (Selection vs. Payment).
        *   `vending_fsm`: Handles drink selection navigation.
        *   `coin_selector`: Manages coin selection in the payment screen.
        *   `price_calculator` & `paid_calculator`: Computes totals and balances.
        *   `change_dispenser`: Greedy algorithm for calculating change.
    *   **Display Logic:**
        *   `vga_sync`: Generates VGA HSYNC/VSYNC timing signals.
        *   `sram`: Block RAM interfaces for sprites (Background, Drinks, Coins).
        *   `text_renderer` & `paid_text_renderer`: Generates text overlays for prices/totals.
        *   `animation_controller`: Manages dispensing animations (falling bottles).

### Memory Organization (SRAM)
The project heavily relies on `.mem` files (located in `backup_mem/`) to initialize Block RAMs for graphics:
- `VendingMachineBg.mem`: Main background.
- `Coin*.mem`: Coin sprites.
- `*DropSheet.mem`: Animation frames for drinks.

## 4. Building and Running

### Prerequisites
- Xilinx Vivado installed.
- Arty A7 Board files installed in Vivado.

### Build Process (Tcl Console)
1.  **Synthesize:**
    ```tcl
    reset_run synth_1
    launch_runs synth_1
    wait_on_run synth_1
    ```
2.  **Implement:**
    ```tcl
    launch_runs impl_1
    wait_on_run impl_1
    ```
3.  **Generate Bitstream:**
    ```tcl
    launch_runs impl_1 -to_step write_bitstream
    wait_on_run impl_1
    ```

### Programming the FPGA
1.  Connect the Arty A7 board via USB.
2.  Open **Hardware Manager** in Vivado.
3.  Execute the following Tcl commands:
    ```tcl
    open_hw_manager
    connect_hw_server
    open_hw_target
    set_property PROGRAM.FILE {lab10/lab10.runs/impl_1/lab10.bit} [get_hw_devices xc7a35t_0]
    program_hw_devices [get_hw_devices xc7a35t_0]
    ```

## 5. Development Conventions

- **Clocking:** 100MHz system clock (`clk`), divided to 25MHz (`vga_clk`) for VGA timing.
- **Reset:** Active low reset (`reset_n` / `rst`).
- **Input Processing:** All button inputs are debounced before use.
- **Naming:**
    - Modules: `snake_case` (e.g., `main_fsm`).
    - Signals: `snake_case` (e.g., `pixel_x`, `total_due`).
    - Constants: `UPPER_CASE` (e.g., `VGA_W`, `STATE_SELECTION`).
- **Files:**
    - Source code in `lab10/lab10.srcs/sources_1/`.
    - Constraints in `lab10/lab10.srcs/constrs_1/`.
    - Memory initialization files in `backup_mem/` (referenced by `sram` modules).
