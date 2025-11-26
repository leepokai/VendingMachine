# Gemini Context: Verilog Vending Machine

## Project Overview

This is a hardware design project that implements a graphical vending machine on a Xilinx Artix-7 FPGA (specifically the Digilent Arty A7 board). The project is written in Verilog.

The system features a 640x480 VGA display to show a 3x3 grid of drink options. Users can select drinks and quantities using the onboard push-buttons. The payment system accepts three coin denominations ($1, $5, $10) and provides change automatically. The core logic is managed by a Finite State Machine (FSM) that transitions between states for selection, payment, dispensing, and errors.

Key components include:
- **FSM Controller**: Manages the main application states.
- **VGA Sync/Controller**: Generates timing and pixel data for the 640x480 display.
- **Memory Modules**: Utilizes on-chip SRAM to store image assets like background, drink sprites, and coin images, which are loaded from `.mem` files.
- **Debouncers & Clock Dividers**: Standard hardware utilities for handling button inputs and generating necessary clock frequencies from the 100MHz system clock.

The project is structured within a Vivado project file (`lab10/lab10.xpr`).

## Building and Running

This is a Xilinx Vivado project. The primary workflow involves using the Vivado Design Suite GUI or Tcl scripting.

**1. Open the Project:**
   Open the `lab10/lab10.xpr` file in Vivado.

**2. Build via Tcl Console:**
   Within the Vivado Tcl console, run the following commands to synthesize the design, run implementation, and generate the final bitstream file.

   ```tcl
   # Synthesize
   reset_run synth_1
   launch_runs synth_1
   wait_on_run synth_1

   # Implement
   launch_runs impl_1
   wait_on_run impl_1

   # Generate bitstream
   launch_runs impl_1 -to_step write_bitstream
   wait_on_run impl_1
   ```
   The output will be located at: `lab10/lab10.runs/impl_1/lab10.bit` (or similar).

**3. Program the FPGA:**
   Connect the Arty A7 board. In the Vivado Hardware Manager, use the following Tcl commands or the GUI equivalent.

   ```tcl
   # In Vivado hardware manager
   open_hw_manager
   connect_hw_server
   open_hw_target
   # Make sure the bitstream path is correct
   set_property PROGRAM.FILE {/path/to/your/project/lab10/lab10.runs/impl_1/vending_machine_top.bit} [get_hw_devices xc7a35t_0]
   program_hw_devices [get_hw_devices xc7a35t_0]
   ```

## Development Conventions

*   **Project Structure**:
    *   **Vivado Project**: The main project is `lab10/lab10.xpr`.
    *   **Verilog Source**: Source files (`.v`) are located in `lab10/lab10.srcs/sources_1/`. The top module appears to be `lab10.v`.
    *   **Constraints**: The physical pin assignments and timing constraints (`.xdc`) are in `lab10/lab10.srcs/constrs_1/`.
    *   **Memory Files**: Memory initialization files (`.mem`) for images and sprites are stored in `backup_mem/`. These files use a 12-bit RGB hex format.

*   **Coding Style**: The design is modular, with clear separation of concerns as outlined in the documentation (e.g., `vga_sync`, `fsm_controller`, `payment_controller`). Button inputs are consistently debounced.

*   **State Management**: The core system behavior is explicitly defined by a set of states: `IDLE`, `SELECTION`, `PAYMENT`, `DISPENSING`, and `ERROR`. All logic should conform to these states.
