# FPGA Vending Machine

A Verilog-based vending machine controller with VGA display for the Arty A7 FPGA development board.

## 🎯 Project Overview


[Demo Video](https://drive.google.com/file/d/1Y9IrSzdBNk1kMw0uLLLjw4yTpecQzooB/view?usp=sharing)


This project implements a fully functional vending machine system on an FPGA with:
- **VGA Display**: 640×480 @ 60Hz graphical interface
- **Drink Selection**: 3×3 grid of 9 beverage options
- **Payment System**: Coin insertion with denominations of $1, $5, and $10
- **Change Making**: Automatic change calculation and dispensing
- **Inventory Management**: Track drink stock and coin availability

## 🖥️ Hardware Requirements

- **FPGA Board**: Digilent Arty A7 (Artix-7)
- **Display**: VGA monitor
- **Input**: 4 push buttons (built-in on Arty A7)
- **Clock**: 100 MHz system clock

## 📖 Documentation

All project documentation is in the `docs/` folder:

| Document | Description |
|----------|-------------|
| **[SPECIFICATION.md](docs/SPECIFICATION.md)** | Complete functional specification with system states, data structures, and display layouts |
| **[TASK_BREAKDOWN.md](docs/tasks/TASK_BREAKDOWN.md)** | Detailed breakdown of all 32 tasks across 5 development phases |
| **[PARALLEL_TASKS.md](docs/tasks/PARALLEL_TASKS.md)** | Parallel execution guide, dependency graph, and resource allocation scenarios |
| **[QUICK_START.md](docs/QUICK_START.md)** | Quick start guide for developers, PMs, and asset creators |
| **[CLAUDE.md](CLAUDE.md)** | Guidance for Claude Code when working in this repository |

## 🚀 Quick Start

### For First-Time Users

1. **Read the specification**:
   ```bash
   cat docs/SPECIFICATION.md
   ```

2. **Review the task breakdown**:
   ```bash
   cat docs/tasks/TASK_BREAKDOWN.md
   ```

3. **Start development** with [QUICK_START.md](docs/QUICK_START.md)

### For Developers

```bash
# Clone the repository
git clone <repository-url>
cd VendingMachine

# Open Vivado project
vivado lab10/lab10.xpr

# Follow task assignments in docs/tasks/TASK_BREAKDOWN.md
```

## 🎮 User Interface

### State 1: Drink Selection
- Use **btn[0]/btn[1]** to navigate between drinks
- Use **btn[2]/btn[3]** to decrease/increase quantity (0-5 max)
- Long press **btn[3]** to proceed to payment

### State 2: Payment
- Use **btn[0]/btn[1]** to select coin denomination ($1, $5, $10)
- Press **btn[3]** to insert selected coin
- Press **btn[2]** to cancel transaction
- System validates change availability before accepting payment

### State 3: Dispensing
- Watch the dispensing animation
- View change breakdown
- Returns to idle after completion

## 📊 Project Status

| Phase | Description | Tasks | Status |
|-------|-------------|-------|--------|
| **Phase 1** | Foundation & Infrastructure | 4 | 🟡 Not Started |
| **Phase 2** | Memory & Asset Management | 5 | 🟡 Not Started |
| **Phase 3** | Core Logic Modules | 5 | 🟡 Not Started |
| **Phase 4** | Display & Rendering | 7 | 🟡 Not Started |
| **Phase 5** | Integration & Testing | 6 | 🟡 Not Started |
| **Total** | | **27** | **0% Complete** |

## 🏗️ Architecture

### Module Hierarchy

```
vending_machine_top (top module)
├── Infrastructure
│   ├── clk_divider (100MHz → 50MHz)
│   ├── button_debouncer (×4)
│   ├── vga_sync (VGA timing)
│   └── sram_controller (image storage)
├── Controllers
│   ├── fsm_controller (main state machine)
│   ├── selection_controller (drink selection)
│   ├── payment_controller (payment logic)
│   ├── coin_manager (coin inventory)
│   └── drink_inventory (stock management)
└── Display
    ├── display_controller (pixel generation)
    ├── sprite_renderer (image rendering)
    ├── text_renderer (text/numbers)
    ├── selection_screen_renderer
    ├── payment_screen_renderer
    └── message_renderer
```

### Memory Layout

Total SRAM: **108,544 words** (18-bit addressing)

```
0x00000 - 0x12BFF: Background image (320×240)
0x12C00 - 0x1DCFF: Drink sprites (9 × 48×48)
0x1DD00 - 0x1E8FF: Coin sprites (3 × 32×32)
0x1E900 - 0x1F7FF: Number sprites (10 × 16×24)
0x1F800 - 0x1FFFF: UI elements
```

## 🛠️ Development

### Prerequisites

- Vivado Design Suite (2018.3 or later)
- Arty A7 board files installed
- Python 3.x (for asset conversion scripts)
- Git for version control

### Build Process

```tcl
# In Vivado TCL console

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

### Programming the FPGA

```tcl
# In Vivado hardware manager
open_hw_manager
connect_hw_server
open_hw_target
set_property PROGRAM.FILE {lab10/lab10.runs/impl_1/vending_machine_top.bit} [get_hw_devices xc7a35t_0]
program_hw_devices [get_hw_devices xc7a35t_0]
```

## 🧪 Testing

Each module includes:
- **Unit testbench** (`*_tb.v`) for individual verification
- **Integration tests** at phase boundaries
- **System testbench** for end-to-end validation

Test scenarios include:
1. Basic purchase (exact payment)
2. Purchase with change
3. Insufficient change error
4. Out of stock error
5. Cancel transaction
6. Multiple item selection

## 📁 Project Structure

```
VendingMachine/
├── README.md                      # This file
├── CLAUDE.md                      # Claude Code guidance
├── docs/                          # All documentation
│   ├── SPECIFICATION.md
│   ├── QUICK_START.md
│   └── tasks/
│       ├── TASK_BREAKDOWN.md
│       └── PARALLEL_TASKS.md
├── lab10/                         # Vivado project (legacy)
│   └── lab10.xpr
├── src/                           # Verilog source (to be created)
│   ├── top/
│   ├── controllers/
│   ├── display/
│   ├── infrastructure/
│   └── testbenches/
├── assets/                        # Image assets (to be created)
│   ├── source/
│   └── mem/
├── scripts/                       # Utility scripts (to be created)
└── constraints/                   # FPGA constraints (to be created)
```

## 🎯 Key Features

### Implemented
- ✅ Comprehensive specification document
- ✅ Detailed task breakdown (32 tasks)
- ✅ Parallel execution guide
- ✅ Project structure defined

### In Development
- 🚧 All Verilog modules (Phase 1-5)
- 🚧 Asset creation (drinks, coins, UI)
- 🚧 Testbenches
- 🚧 Integration

### Planned
- 📋 Hardware validation
- 📋 Performance optimization
- 📋 User manual
- 📋 Demo video

## 🤝 Contributing

This project uses a task-based development approach:

1. **Pick a task** from [TASK_BREAKDOWN.md](docs/tasks/TASK_BREAKDOWN.md)
2. **Check dependencies** in [PARALLEL_TASKS.md](docs/tasks/PARALLEL_TASKS.md)
3. **Create a branch**: `git checkout -b feature/task-X.Y-name`
4. **Develop with testbench**: Write tests first (TDD)
5. **Submit pull request** when task is complete

## 📋 Task Phases

| Phase | Focus | Duration |
|-------|-------|----------|
| 1 | Foundation (Clock, Buttons, VGA) | 1-2 days |
| 2 | Memory & Assets | 2-3 days |
| 3 | Core Logic (FSM, Controllers) | 3-4 days |
| 4 | Display Rendering | 4-5 days |
| 5 | Integration & Testing | 2-3 days |

**Total Estimated Time**: 12-17 days (with parallelization)

## 🎓 Learning Outcomes

Working on this project, you'll learn:
- Finite State Machine (FSM) design in Verilog
- VGA display controller implementation
- Memory management (BRAM inference)
- Button debouncing and edge detection
- FPGA resource optimization
- Parallel development workflows
- Hardware-software integration

## ⚖️ License

[Specify your license here]

## 👥 Authors

- **Original Lab**: Based on lab10 from National Chiao Tung University
- **Vending Machine Spec**: [Your name/team]

## 📞 Support

- **Issues**: Use GitHub Issues for bug reports
- **Questions**: Check [SPECIFICATION.md](docs/SPECIFICATION.md) first
- **Development**: See [QUICK_START.md](docs/QUICK_START.md)

## 🔗 Links

- [Arty A7 Reference Manual](https://reference.digilentinc.com/reference/programmable-logic/arty-a7/start)
- [Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado.html)
- [Verilog HDL Reference](https://verilog.renerta.com/)

---

**Status**: Specification Complete, Development Ready to Start
**Last Updated**: 2025-11-26
