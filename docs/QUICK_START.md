# Vending Machine Project - Quick Start Guide

## 📋 Project Documents

All project documentation is located in the `docs/` folder:

- **`SPECIFICATION.md`**: Complete functional specification
- **`tasks/TASK_BREAKDOWN.md`**: Detailed task list with 32 subtasks
- **`tasks/PARALLEL_TASKS.md`**: Parallel execution guide and task dependencies
- **`QUICK_START.md`**: This file

## 🚀 Getting Started

### For Project Managers / Team Leads

1. **Read the Specification**:
   ```
   docs/SPECIFICATION.md
   ```
   Understand the system states, user interface, and requirements.

2. **Review Task Breakdown**:
   ```
   docs/tasks/TASK_BREAKDOWN.md
   ```
   Familiarize yourself with all 32 tasks across 5 phases.

3. **Plan Resource Allocation**:
   ```
   docs/tasks/PARALLEL_TASKS.md
   ```
   See parallelization scenarios for 1-4 developers.

4. **Assign Initial Tasks**:
   Start with Phase 1 tasks (1.1 - 1.4), which can run in parallel.

### For Developers

1. **Set Up Environment**:
   ```bash
   # Open Vivado project
   vivado lab10/lab10.xpr
   ```

2. **Read Your Assigned Task**:
   - Find your task in `docs/tasks/TASK_BREAKDOWN.md`
   - Note dependencies and deliverables
   - Check if your task is in a parallel group

3. **Create Your Module**:
   - Write Verilog module as specified
   - Create testbench (`_tb.v`) for your module
   - Test independently before integration

4. **Follow TDD Approach**:
   ```verilog
   // 1. Write testbench first
   // 2. Define module interface
   // 3. Implement module logic
   // 4. Simulate and verify
   // 5. Mark task complete
   ```

### For Asset Creators (Graphics/Artists)

1. **Review Asset Requirements**:
   - Background: 320×240 pixels
   - Drinks: 9 sprites, each 48×48 pixels
   - Coins: 3 sprites, each 32×32 pixels
   - Numbers: 10 digits, each 16×24 pixels
   - UI Elements: Various sizes

2. **Color Format**:
   - 12-bit RGB (4 bits per channel)
   - Format: `0xRGB` where R, G, B are each 0-F

3. **Output Format**:
   - `.mem` files (hexadecimal, one value per line)
   - Use provided conversion script (Task 2.5)

4. **Start with Placeholders**:
   - Simple colored rectangles are fine initially
   - Allows parallel development while you create final assets

## 📊 Project Phases Overview

### Phase 1: Foundation (Days 1-2)
**Goal**: Set up infrastructure
- [x] Project setup
- [ ] Clock generation
- [ ] Button debouncing
- [ ] VGA sync

**Parallel**: All tasks after project setup

### Phase 2: Memory & Assets (Days 2-4)
**Goal**: Prepare image storage and assets
- [ ] SRAM controller
- [ ] Background image
- [ ] Drink sprites
- [ ] Coin/number sprites
- [ ] Memory initialization

**Parallel**: All asset tasks can run simultaneously

### Phase 3: Core Logic (Days 5-8)
**Goal**: Implement business logic
- [ ] Main FSM (CRITICAL - must complete first)
- [ ] Selection controller
- [ ] Payment controller
- [ ] Inventory managers

**Parallel**: After FSM, all controllers can run in parallel

### Phase 4: Display (Days 9-13)
**Goal**: Implement VGA rendering
- [ ] Display controller hub (CRITICAL)
- [ ] Sprite renderer
- [ ] Text renderer
- [ ] Screen renderers (selection, payment, messages)

**Parallel**: Multiple renderers can be developed simultaneously

### Phase 5: Integration (Days 14-17)
**Goal**: Bring it all together
- [ ] Top module integration
- [ ] System testbench
- [ ] Synthesis & timing
- [ ] Hardware testing
- [ ] Bug fixes
- [ ] Documentation

**Sequential**: Most tasks here must be done in order

## 🎯 Critical Path

These tasks MUST be completed in order (no parallelization):

```
1.1 Project Setup
  ↓
3.1 Main FSM Controller ⚠️
  ↓
4.1 Display Controller Hub ⚠️
  ↓
4.5 Selection Screen Renderer ⚠️
  ↓
5.1 Top Module Integration ⚠️
  ↓
5.2-5.4 Testing & Deployment
```

**Critical Path Duration**: ~8-10 days minimum

Assign your best developers to these tasks!

## 📁 Recommended Folder Structure

```
VendingMachine/
├── docs/                          # Documentation
│   ├── SPECIFICATION.md
│   ├── QUICK_START.md
│   └── tasks/
│       ├── TASK_BREAKDOWN.md
│       └── PARALLEL_TASKS.md
├── lab10/                         # Vivado project (legacy)
├── src/                           # New Verilog source files
│   ├── top/
│   │   └── vending_machine_top.v
│   ├── controllers/
│   │   ├── fsm_controller.v
│   │   ├── selection_controller.v
│   │   ├── payment_controller.v
│   │   └── coin_manager.v
│   ├── display/
│   │   ├── display_controller.v
│   │   ├── sprite_renderer.v
│   │   ├── text_renderer.v
│   │   └── screen_renderers/
│   ├── infrastructure/
│   │   ├── clk_divider.v
│   │   ├── button_debouncer.v
│   │   ├── vga_sync.v
│   │   └── sram_controller.v
│   └── testbenches/
│       └── *.tb.v
├── assets/                        # Image assets
│   ├── source/                    # Original images (PNG, etc.)
│   └── mem/                       # Generated .mem files
│       ├── background.mem
│       ├── drinks.mem
│       ├── coins.mem
│       ├── numbers.mem
│       └── images.mem (combined)
├── scripts/                       # Utility scripts
│   └── generate_memory.py
└── constraints/
    └── vending_machine.xdc
```

## 🛠️ Development Workflow

### Individual Module Development

1. **Create Branch**:
   ```bash
   git checkout -b feature/task-X.Y-module-name
   ```

2. **Develop Module**:
   ```verilog
   // src/controllers/my_module.v
   module my_module(...);
     // Implementation
   endmodule
   ```

3. **Create Testbench**:
   ```verilog
   // src/testbenches/my_module_tb.v
   module my_module_tb;
     // Test cases
   endmodule
   ```

4. **Simulate**:
   ```tcl
   # In Vivado
   add_files src/controllers/my_module.v
   add_files -fileset sim_1 src/testbenches/my_module_tb.v
   launch_simulation
   ```

5. **Verify & Commit**:
   ```bash
   git add src/controllers/my_module.v src/testbenches/my_module_tb.v
   git commit -m "Implement Task X.Y: Module Name"
   git push origin feature/task-X.Y-module-name
   ```

### Integration Workflow

1. **Incremental Integration**:
   - Don't wait for all modules to integrate
   - Integrate phase-by-phase
   - Test after each integration

2. **Sync Points**:
   - After Phase 1: Integrate infrastructure
   - After Phase 3: Integrate controllers
   - After Phase 4: Integrate display
   - Phase 5: Final integration

3. **Testing**:
   - Module-level tests throughout development
   - Integration tests at sync points
   - System-level test before hardware deployment

## ⚡ Quick Commands

### Vivado TCL Commands

```tcl
# Open project
open_project lab10/lab10.xpr

# Add new source file
add_files src/controllers/new_module.v

# Run simulation
launch_simulation

# Synthesize
reset_run synth_1
launch_runs synth_1
wait_on_run synth_1

# Implement
launch_runs impl_1
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream

# Program FPGA
open_hw_manager
connect_hw_server
open_hw_target
program_hw_devices [get_hw_devices xc7a35t_0]
```

### Asset Conversion (Example)

```python
# scripts/generate_memory.py
# Convert PNG to .mem format
from PIL import Image

def convert_image_to_mem(image_path, output_path):
    img = Image.open(image_path)
    pixels = img.load()

    with open(output_path, 'w') as f:
        for y in range(img.height):
            for x in range(img.width):
                r, g, b = pixels[x, y][:3]
                # Convert 8-bit RGB to 4-bit RGB
                r4 = r >> 4
                g4 = g >> 4
                b4 = b >> 4
                # Write as 12-bit hex value
                f.write(f"{(r4 << 8) | (g4 << 4) | b4:03X}\n")
```

## 📞 Communication Channels

### Daily Standup Topics
- Which task are you working on?
- Any blockers or dependencies?
- Interface changes that affect others?
- Sync point progress?

### Documentation Updates
- Update task status in TASK_BREAKDOWN.md
- Document interface changes immediately
- Update PARALLEL_TASKS.md progress tracker
- Add notes in SPECIFICATION.md if requirements clarified

## ⚠️ Common Pitfalls

1. **Starting Integration Too Late**:
   - Integrate incrementally, not all at once

2. **Ignoring Dependencies**:
   - Check PARALLEL_TASKS.md before starting a task
   - Wait for sync points

3. **No Individual Testing**:
   - Always create testbench for your module
   - Don't rely on system-level testing to catch bugs

4. **Poor Interface Documentation**:
   - Document your module's interface clearly
   - Others depend on you getting it right

5. **Skipping Asset Placeholders**:
   - Use simple colored rectangles as temporary assets
   - Don't block development waiting for final graphics

## 📈 Progress Tracking

Use this checklist daily:

- [ ] Check assigned tasks in TASK_BREAKDOWN.md
- [ ] Verify dependencies are met
- [ ] Create/update testbench
- [ ] Simulate and verify functionality
- [ ] Document interface if module is used by others
- [ ] Commit and push code
- [ ] Update task status
- [ ] Communicate blockers to team

## 🎓 Learning Resources

### Verilog Basics
- Clock domain crossing
- FSM design patterns
- Memory inference (BRAM)
- VGA timing principles

### FPGA Tools
- Vivado simulation
- Synthesis reports
- Timing analysis
- Bitstream generation

### This Project
- Read SPECIFICATION.md first
- Study the state diagram
- Understand memory layout
- Review module hierarchy

## 🎉 Success Criteria

Your project is complete when:

- ✅ All 32 tasks marked complete
- ✅ System testbench passes all scenarios
- ✅ Synthesis meets timing (100 MHz)
- ✅ Hardware test successful on Arty A7
- ✅ User can select drinks, pay, receive change
- ✅ All error conditions handled gracefully
- ✅ VGA display shows correct screens
- ✅ All 4 buttons work as specified

## 📝 Next Steps

1. **Read SPECIFICATION.md** to understand what you're building
2. **Review TASK_BREAKDOWN.md** to see all tasks
3. **Check PARALLEL_TASKS.md** for your role assignment
4. **Start with Task 1.1** (Project Setup)
5. **Begin parallel development** with your team

Good luck! 🚀
