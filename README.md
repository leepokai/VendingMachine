# FPGA Vending Machine

A vending machine written in Verilog for the Digilent Arty A7-35T, with a 640×480 VGA interface driven by the board's four push buttons.

[Demo video](https://drive.google.com/file/d/1Y9IrSzdBNk1kMw0uLLLjw4yTpecQzooB/view?usp=sharing)

## Features

- 3×3 drink grid with per-item quantities and a shopping cart
- Payment with coins and bills, running total of the amount paid
- Change making that checks the machine's coin inventory first, with refund on failure
- Dispensing animation and a breakdown of the change returned
- Sprites and background stored in block RAM, loaded from `.mem` files

## Hardware

- Digilent Arty A7-35T (`xc7a35ticsg324-1L`), 100 MHz system clock
- VGA output, 12-bit color (pin mapping in `lab10/lab10.srcs/constrs_1/lab10.xdc`)
- 4 on-board push buttons

## Build

1. Open `lab10/lab10.xpr` in Vivado.
2. Run synthesis, implementation, and **Generate Bitstream**.
3. Program the board from the Hardware Manager.

## Source layout

All RTL is in `lab10/lab10.srcs/sources_1/`:

| Area | Modules |
|---|---|
| Top level | `lab10.v` |
| Control | `main_fsm.v`, `vending_fsm.v`, `debounce.v`, `clk_divider.v` |
| Payment and change | `coin_selector.v`, `price_calculator.v`, `paid_calculator.v`, `change_dispenser.v`, `bin2bcd.v` |
| Display | `vga_sync.v`, `sram.v`, `text_renderer.v`, `cart_list_renderer.v`, `animation_controller.v`, `*_display.v`, `*_text_renderer.v` |

The full functional spec (states, inventory, change-making algorithm, memory files) is in [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md).

## How it was built

The team wrote the spec first, then developed the RTL with AI coding agents. [`CLAUDE.md`](CLAUDE.md) and [`GEMINI.md`](GEMINI.md) are the context files given to Claude Code and Gemini CLI.

## Authors

Final project for the Digital Circuit Lab course at National Yang Ming Chiao Tung University (NYCU), Fall 2025.

- [@leepokai](https://github.com/leepokai)
- [@monesijd](https://github.com/monesijd)
- [@anby0205](https://github.com/anby0205)
- [@Nycu-acc](https://github.com/Nycu-acc)

## License

MIT, see [LICENSE](LICENSE). This covers the team's original work only. Files that came from the course lab template or from Digilent keep their original terms and are not relicensed: `vga_sync.v` (© Laboratory System Integration and Silicon Implementation, all rights reserved), `clk_divider.v`, `sram.v`, and `lab10.xdc` (based on Digilent's Arty master XDC).
