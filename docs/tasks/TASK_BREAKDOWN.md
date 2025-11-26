# Vending Machine - Task Breakdown

## Task Organization

Tasks are organized into phases. Tasks marked with **[PARALLEL]** can be developed independently and in parallel with other parallel tasks in the same phase.

---

## Phase 1: Foundation & Infrastructure

### Task 1.1: Project Setup ⚙️
**Priority**: HIGH
**Estimated Complexity**: Low
**Dependencies**: None

**Description**: Set up Vivado project structure and basic configuration

**Subtasks**:
- [ ] Create new Vivado project for Arty A7
- [ ] Copy and modify constraints file (lab10.xdc)
- [ ] Set up project directory structure
- [ ] Configure synthesis and implementation settings
- [ ] Create initial top module skeleton

**Deliverables**:
- Vivado project file (.xpr)
- Updated constraints file
- Empty top module structure

---

### Task 1.2: Clock and Reset Infrastructure ⚙️ **[PARALLEL]**
**Priority**: HIGH
**Estimated Complexity**: Low
**Dependencies**: None

**Description**: Set up clock generation and reset synchronization

**Subtasks**:
- [ ] Reuse/verify clk_divider module (100MHz → 50MHz)
- [ ] Create reset synchronizer module
- [ ] Generate 25MHz pixel clock for VGA
- [ ] Add clock domain crossing logic if needed
- [ ] Verify timing constraints

**Deliverables**:
- `clk_divider.v` (verified/reused)
- `reset_sync.v`
- Timing constraint updates

**Files**: `clk_divider.v`, `reset_sync.v`

---

### Task 1.3: Button Debouncer Module ⚙️ **[PARALLEL]**
**Priority**: HIGH
**Estimated Complexity**: Medium
**Dependencies**: None

**Description**: Create robust button debouncing with edge detection

**Subtasks**:
- [ ] Design debouncer FSM (20ms debounce time)
- [ ] Implement edge detection (rising/falling)
- [ ] Add long-press detection (for confirm action)
- [ ] Create testbench for button debouncer
- [ ] Verify timing: 2,000,000 cycles @ 100MHz = 20ms

**Deliverables**:
- `button_debouncer.v`
- `button_debouncer_tb.v`

**Parameters**:
- Debounce time: 20ms
- Long press threshold: 1 second

**Files**: `button_debouncer.v`, `button_debouncer_tb.v`

---

### Task 1.4: VGA Sync Module ⚙️ **[PARALLEL]**
**Priority**: HIGH
**Estimated Complexity**: Low
**Dependencies**: None

**Description**: Reuse and verify VGA sync signal generator

**Subtasks**:
- [ ] Copy vga_sync.v from lab10
- [ ] Verify 640×480 @ 60Hz timing parameters
- [ ] Test sync signal generation
- [ ] Add visible area indicators
- [ ] Create simple test pattern generator

**Deliverables**:
- `vga_sync.v` (verified)
- Simple test pattern for VGA verification

**Files**: `vga_sync.v`

---

## Phase 2: Memory & Asset Management

### Task 2.1: SRAM Controller Module 🧠 **[PARALLEL]**
**Priority**: HIGH
**Estimated Complexity**: Medium
**Dependencies**: None

**Description**: Design unified SRAM module for all image assets

**Subtasks**:
- [ ] Calculate total memory requirement (108,544 words)
- [ ] Design memory address mapping scheme
- [ ] Create parameterized SRAM module
- [ ] Implement memory initialization from .mem files
- [ ] Add address decoder for different asset regions

**Deliverables**:
- `sram_controller.v`
- Memory map documentation

**Memory Map**:
```
0x00000 - 0x12BFF: Background (76,800 words)
0x12C00 - 0x1DCFF: Drinks (20,736 words)
0x1DD00 - 0x1E8FF: Coins (3,072 words)
0x1E900 - 0x1F7FF: Numbers (3,840 words)
0x1F800 - 0x1FFFF: UI Elements (2,048 words)
```

**Files**: `sram_controller.v`

---

### Task 2.2: Asset Preparation - Background 🎨 **[PARALLEL]**
**Priority**: MEDIUM
**Estimated Complexity**: Low
**Dependencies**: None

**Description**: Create background image asset

**Subtasks**:
- [ ] Design/obtain 320×240 background image
- [ ] Convert to 12-bit RGB format
- [ ] Generate background.mem file
- [ ] Verify format (hex, one value per line)
- [ ] Test loading in SRAM

**Deliverables**:
- `background.mem` (76,800 entries)
- Conversion script/tool documentation

**Files**: `assets/background.mem`

---

### Task 2.3: Asset Preparation - Drinks 🎨 **[PARALLEL]**
**Priority**: MEDIUM
**Estimated Complexity**: Medium
**Dependencies**: None

**Description**: Create 9 drink sprite images

**Subtasks**:
- [ ] Design/obtain 9 drink images (48×48 each)
- [ ] Convert to 12-bit RGB format
- [ ] Assign drink IDs (0-8)
- [ ] Generate drinks.mem file (sequential storage)
- [ ] Create asset index documentation

**Deliverables**:
- `drinks.mem` (20,736 entries)
- Drink index mapping table

**Drink Mapping**:
```
Drink 0 (Offset 0x0000): Cola
Drink 1 (Offset 0x0900): Orange Juice
Drink 2 (Offset 0x1200): Water
... (etc)
```

**Files**: `assets/drinks.mem`

---

### Task 2.4: Asset Preparation - Coins & UI 🎨 **[PARALLEL]**
**Priority**: MEDIUM
**Estimated Complexity**: Medium
**Dependencies**: None

**Description**: Create coin sprites and UI elements

**Subtasks**:
- [ ] Design coin images: $1, $5, $10 (32×32 each)
- [ ] Design number sprites 0-9 (16×24 each)
- [ ] Design selection cursor/highlight
- [ ] Design button icons and indicators
- [ ] Convert all to 12-bit RGB
- [ ] Generate coins.mem, numbers.mem, ui_elements.mem

**Deliverables**:
- `coins.mem` (3,072 entries)
- `numbers.mem` (3,840 entries)
- `ui_elements.mem` (4,096 entries)
- Asset documentation

**Files**: `assets/coins.mem`, `assets/numbers.mem`, `assets/ui_elements.mem`

---

### Task 2.5: Memory Initialization Helper 🛠️
**Priority**: MEDIUM
**Estimated Complexity**: Low
**Dependencies**: Task 2.1, 2.2, 2.3, 2.4

**Description**: Combine all .mem files into single initialization

**Subtasks**:
- [ ] Create script to concatenate all .mem files
- [ ] Verify memory addresses match mapping
- [ ] Generate master images.mem file
- [ ] Test SRAM initialization in simulation
- [ ] Document memory layout

**Deliverables**:
- `generate_memory.py` or similar script
- `images.mem` (combined file)
- Memory layout diagram

**Files**: `scripts/generate_memory.py`, `assets/images.mem`

---

## Phase 3: Core Logic Modules

### Task 3.1: Main FSM Controller 🎮
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 1.2, 1.3

**Description**: Implement main state machine for vending machine

**Subtasks**:
- [ ] Define state encoding (IDLE, SELECTION, PAYMENT, DISPENSING, ERROR)
- [ ] Implement state transitions
- [ ] Add timeout counters for each state
- [ ] Implement state-specific output enables
- [ ] Create FSM testbench
- [ ] Add LED indicators for states

**Deliverables**:
- `fsm_controller.v`
- `fsm_controller_tb.v`
- State diagram documentation

**States**:
```
IDLE → SELECTION → PAYMENT → DISPENSING → IDLE
              ↓        ↓
           ERROR ←────┘
```

**Files**: `fsm_controller.v`, `fsm_controller_tb.v`

---

### Task 3.2: Selection Controller 🥤 **[PARALLEL with 3.3, 3.4]**
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 3.1

**Description**: Implement drink selection logic

**Subtasks**:
- [ ] Create 3×3 grid navigation logic
- [ ] Implement quantity increment/decrement (0-5 limit)
- [ ] Add current selection register
- [ ] Calculate total items and total price
- [ ] Implement stock checking
- [ ] Add selection validation
- [ ] Create testbench

**Deliverables**:
- `selection_controller.v`
- `selection_controller_tb.v`

**Inputs**:
- Button signals (debounced)
- Current state from FSM

**Outputs**:
- Selected quantities [8:0][2:0]
- Current cursor position [3:0]
- Total price [15:0]
- Selection valid flag

**Files**: `selection_controller.v`, `selection_controller_tb.v`

---

### Task 3.3: Payment Controller 💰 **[PARALLEL with 3.2, 3.4]**
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 3.1

**Description**: Implement payment and change-making logic

**Subtasks**:
- [ ] Implement coin selection logic (1, 5, 10)
- [ ] Create payment accumulator
- [ ] Implement change-making algorithm (greedy)
- [ ] Add change validation logic
- [ ] Implement payment state tracking
- [ ] Create testbench with various scenarios
- [ ] Test edge cases (exact change, insufficient change)

**Deliverables**:
- `payment_controller.v`
- `payment_controller_tb.v`

**Change Algorithm**:
```verilog
// Greedy: largest coins first
// Validate against coin inventory
// Return success/failure + coin breakdown
```

**Files**: `payment_controller.v`, `payment_controller_tb.v`

---

### Task 3.4: Coin Inventory Manager 🪙 **[PARALLEL with 3.2, 3.3]**
**Priority**: HIGH
**Estimated Complexity**: Medium
**Dependencies**: Task 3.1

**Description**: Track vending machine coin inventory

**Subtasks**:
- [ ] Create coin count registers (1, 5, 10)
- [ ] Implement coin addition (on payment)
- [ ] Implement coin subtraction (on change dispensing)
- [ ] Add inventory query interface
- [ ] Prevent underflow (safety checks)
- [ ] Add reset to initial values
- [ ] Create testbench

**Deliverables**:
- `coin_manager.v`
- `coin_manager_tb.v`

**Initial Values**:
- $1: 50 coins
- $5: 20 coins
- $10: 15 coins

**Files**: `coin_manager.v`, `coin_manager_tb.v`

---

### Task 3.5: Drink Inventory Manager 🥫
**Priority**: MEDIUM
**Estimated Complexity**: Medium
**Dependencies**: Task 3.2

**Description**: Track drink stock levels

**Subtasks**:
- [ ] Create stock registers for 9 drinks
- [ ] Create price registers for 9 drinks
- [ ] Implement stock decrement on purchase
- [ ] Add stock query interface
- [ ] Add low-stock warning logic
- [ ] Prevent negative stock
- [ ] Create testbench

**Deliverables**:
- `drink_inventory.v`
- `drink_inventory_tb.v`

**Initial Values**:
- All drinks: 10 units
- Prices: As defined in spec

**Files**: `drink_inventory.v`, `drink_inventory_tb.v`

---

## Phase 4: Display & Rendering

### Task 4.1: Display Controller Hub 🖥️
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 1.4, 2.1

**Description**: Main display controller that coordinates all renderers

**Subtasks**:
- [ ] Create pixel address generation unit (AGU)
- [ ] Implement renderer multiplexer (select active renderer per state)
- [ ] Add RGB output pipeline
- [ ] Implement sprite lookup logic
- [ ] Add text positioning system
- [ ] Create coordinate transformation utilities
- [ ] Integrate with VGA sync

**Deliverables**:
- `display_controller.v`

**Files**: `display_controller.v`

---

### Task 4.2: Background Renderer 🌆 **[PARALLEL with 4.3]**
**Priority**: MEDIUM
**Estimated Complexity**: Low
**Dependencies**: Task 4.1

**Description**: Render static background image

**Subtasks**:
- [ ] Implement 320×240 to 640×480 scaling (2x)
- [ ] Add SRAM address calculation for background
- [ ] Pipeline pixel fetching
- [ ] Handle VGA sync periods (blank to black)
- [ ] Test with background.mem

**Deliverables**:
- `background_renderer.v`

**Files**: `background_renderer.v`

---

### Task 4.3: Sprite Renderer 🎨 **[PARALLEL with 4.2]**
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 4.1

**Description**: Generic sprite rendering engine

**Subtasks**:
- [ ] Create sprite positioning system (x, y, width, height)
- [ ] Implement transparency/color-key support
- [ ] Add sprite scaling support (if needed)
- [ ] Implement sprite sheet indexing
- [ ] Add bounds checking
- [ ] Create priority/layering system
- [ ] Test with drink and coin sprites

**Deliverables**:
- `sprite_renderer.v`

**Features**:
- Support multiple sprites simultaneously
- Transparency for overlays
- Configurable sprite size

**Files**: `sprite_renderer.v`

---

### Task 4.4: Text & Number Renderer 🔢
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 4.3

**Description**: Render text and numbers using number sprites

**Subtasks**:
- [ ] Create digit-to-sprite mapping (0-9)
- [ ] Implement multi-digit number rendering
- [ ] Add decimal number formatting
- [ ] Implement text positioning system
- [ ] Add text alignment (left, center, right)
- [ ] Support currency formatting ($XX)
- [ ] Create character spacing logic

**Deliverables**:
- `text_renderer.v`

**Capabilities**:
- Render prices: "$10"
- Render quantities: "Qty: 3"
- Render totals: "Total: $45"

**Files**: `text_renderer.v`

---

### Task 4.5: Selection Screen Renderer 🍹
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 4.2, 4.3, 4.4

**Description**: Render drink selection screen (3×3 grid)

**Subtasks**:
- [ ] Design grid layout (3×3, 160px cells at 2x scale)
- [ ] Implement drink sprite positioning
- [ ] Add selection highlight/cursor
- [ ] Render drink prices below sprites
- [ ] Render quantity indicators
- [ ] Add bottom info bar (total items, total price)
- [ ] Implement grid borders/separators
- [ ] Test with all 9 drinks

**Deliverables**:
- `selection_screen_renderer.v`

**Layout**:
```
Each cell: ~160×160 pixels (80×80 native, scaled 2x)
  - Drink sprite: 48×48 (centered)
  - Price text: below sprite
  - Quantity: "Qty: X"
  - Highlight overlay when selected
```

**Files**: `selection_screen_renderer.v`

---

### Task 4.6: Payment Screen Renderer 💳
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 4.3, 4.4

**Description**: Render payment interface screen

**Subtasks**:
- [ ] Design layout for payment screen
- [ ] Render order summary (items + prices)
- [ ] Display total amount due
- [ ] Show amount paid and remaining
- [ ] Render coin selection UI (highlight selected)
- [ ] Display machine change availability
- [ ] Add instruction text at bottom
- [ ] Implement scrolling if order summary is long

**Deliverables**:
- `payment_screen_renderer.v`

**Sections**:
1. Top: Order summary
2. Middle: Payment status
3. Coin selection with sprites
4. Bottom: Instructions

**Files**: `payment_screen_renderer.v`

---

### Task 4.7: Dispensing & Message Renderer 📦 **[PARALLEL with 4.6]**
**Priority**: MEDIUM
**Estimated Complexity**: Medium
**Dependencies**: Task 4.4

**Description**: Render dispensing animation and messages

**Subtasks**:
- [ ] Create "Dispensing..." message renderer
- [ ] Add animated spinner/progress indicator
- [ ] Render change breakdown
- [ ] Display transaction summary
- [ ] Add success/error message rendering
- [ ] Implement simple animations (blink, scroll)

**Deliverables**:
- `message_renderer.v`

**Messages**:
- "Dispensing drinks..."
- "Change: $X ($1×a, $5×b, $10×c)"
- "Thank you!"
- "Error: Cannot make change"
- "Error: Out of stock"

**Files**: `message_renderer.v`

---

## Phase 5: Integration & Testing

### Task 5.1: Top Module Integration 🔧
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: All previous tasks

**Description**: Integrate all modules into top-level

**Subtasks**:
- [ ] Instantiate all submodules
- [ ] Connect FSM to controllers
- [ ] Wire button inputs through debouncers
- [ ] Connect display controller to VGA output
- [ ] Wire SRAM to display and controllers
- [ ] Connect LED outputs
- [ ] Add debug outputs for simulation
- [ ] Verify no unconnected wires

**Deliverables**:
- `vending_machine_top.v` (new top module)
- Integration documentation
- Port mapping diagram

**Files**: `vending_machine_top.v`

---

### Task 5.2: Simulation Testbench 🧪
**Priority**: HIGH
**Estimated Complexity**: High
**Dependencies**: Task 5.1

**Description**: Create comprehensive system-level testbench

**Subtasks**:
- [ ] Create full system testbench
- [ ] Simulate button press sequences
- [ ] Test all state transitions
- [ ] Verify payment calculations
- [ ] Test change-making algorithm
- [ ] Simulate error conditions
- [ ] Generate VGA waveforms for verification
- [ ] Add assertions for critical paths

**Test Scenarios**:
1. Simple purchase (exact payment)
2. Purchase with change
3. Insufficient change error
4. Out of stock error
5. Cancel transaction
6. Multiple item purchase

**Deliverables**:
- `vending_machine_top_tb.v`
- Simulation results documentation

**Files**: `vending_machine_top_tb.v`

---

### Task 5.3: Synthesis & Timing Analysis ⚡
**Priority**: HIGH
**Estimated Complexity**: Medium
**Dependencies**: Task 5.1

**Description**: Synthesize design and meet timing constraints

**Subtasks**:
- [ ] Run synthesis in Vivado
- [ ] Analyze resource utilization
- [ ] Run implementation
- [ ] Perform timing analysis
- [ ] Fix any timing violations
- [ ] Optimize critical paths if needed
- [ ] Verify BRAM inference for SRAM
- [ ] Generate resource utilization report

**Deliverables**:
- Synthesis report
- Timing report
- Resource utilization report
- Optimization notes

**Timing Goals**:
- 100 MHz system clock
- 50 MHz VGA clock
- All setup/hold times met

---

### Task 5.4: Hardware Testing 🔬
**Priority**: HIGH
**Estimated Complexity**: Medium
**Dependencies**: Task 5.3

**Description**: Test on actual Arty A7 hardware

**Subtasks**:
- [ ] Generate bitstream
- [ ] Program FPGA
- [ ] Test VGA output on monitor
- [ ] Verify button functionality
- [ ] Test complete user flow
- [ ] Verify all states work correctly
- [ ] Test edge cases on hardware
- [ ] Document any hardware-specific issues
- [ ] Verify LED indicators

**Test Checklist**:
- [ ] Display shows correctly on VGA
- [ ] All buttons respond
- [ ] Selection navigation works
- [ ] Payment logic correct
- [ ] Change calculated properly
- [ ] State transitions smooth
- [ ] No visual glitches

**Deliverables**:
- Hardware test report
- Video/photos of working system
- Bug list (if any)

---

### Task 5.5: Bug Fixes & Optimization 🐛
**Priority**: MEDIUM
**Estimated Complexity**: Variable
**Dependencies**: Task 5.4

**Description**: Fix issues found during testing

**Subtasks**:
- [ ] Address simulation bugs
- [ ] Fix hardware bugs
- [ ] Optimize resource usage if needed
- [ ] Improve timing if violations exist
- [ ] Polish user experience
- [ ] Add final visual improvements

**Deliverables**:
- Bug fix documentation
- Updated source files
- Optimization report

---

### Task 5.6: Documentation & Cleanup 📝
**Priority**: LOW
**Estimated Complexity**: Low
**Dependencies**: Task 5.5

**Description**: Final documentation and code cleanup

**Subtasks**:
- [ ] Add comments to all modules
- [ ] Create module hierarchy diagram
- [ ] Write user manual
- [ ] Document test procedures
- [ ] Create demo video/instructions
- [ ] Update CLAUDE.md
- [ ] Clean up unused files
- [ ] Archive old versions

**Deliverables**:
- Comprehensive code comments
- User manual
- System architecture document
- Demo materials
- Updated CLAUDE.md

---

## Summary

### Total Tasks: 32

### By Priority:
- **HIGH**: 18 tasks
- **MEDIUM**: 12 tasks
- **LOW**: 2 tasks

### Parallel Task Groups:

**Group 1 (Phase 1)**: Can all start immediately
- Task 1.2: Clock Infrastructure
- Task 1.3: Button Debouncer
- Task 1.4: VGA Sync

**Group 2 (Phase 2)**: Can all start after Phase 1
- Task 2.1: SRAM Controller
- Task 2.2: Background Asset
- Task 2.3: Drink Assets
- Task 2.4: Coin/UI Assets

**Group 3 (Phase 3)**: Can start after FSM (3.1)
- Task 3.2: Selection Controller
- Task 3.3: Payment Controller
- Task 3.4: Coin Manager

**Group 4 (Phase 4)**: Can start after Display Hub (4.1)
- Task 4.2: Background Renderer
- Task 4.3: Sprite Renderer
- Task 4.6: Payment Screen (parallel with 4.7)
- Task 4.7: Message Renderer (parallel with 4.6)

### Critical Path:
```
1.1 → 1.2 → 3.1 → 3.2/3.3 → 5.1 → 5.2 → 5.3 → 5.4
      ↓
     1.4 → 4.1 → 4.3 → 4.4 → 4.5/4.6 → 5.1
```

### Estimated Timeline:
- **Phase 1**: 1-2 days
- **Phase 2**: 2-3 days
- **Phase 3**: 3-4 days
- **Phase 4**: 4-5 days
- **Phase 5**: 2-3 days

**Total**: ~12-17 days (with parallelization)

---

## Notes
- Tasks marked **[PARALLEL]** can be assigned to different team members
- Asset creation (Phase 2) can be done by non-Verilog developers
- Simulation should be done incrementally as modules complete
- Don't wait for all assets before starting renderer development (use placeholders)
