# Vending Machine Specification

## Project Overview

A Verilog-based vending machine controller with VGA display for the Arty A7 FPGA board. The system allows users to select drinks from a 3×3 grid, specify quantities, make payments with coins, and receive change.

## Hardware Requirements

- **Target Board**: Arty A7 (Artix-7 FPGA)
- **Display**: VGA output (640×480 @ 60Hz)
- **Input**: 4 push buttons (usr_btn[3:0])
- **Output**: 4 LEDs (usr_led[3:0]) for status indication
- **Clock**: 100 MHz system clock

## System States

### State 0: IDLE / Welcome Screen
- Display vending machine welcome screen
- Wait for user to press any button to start
- Transition to SELECTION state on button press

### State 1: SELECTION (Drink Selection)
- **Display**: 3×3 grid showing 9 drink options
- **Each Drink Shows**:
  - Drink image/icon
  - Drink name
  - Price
  - Current quantity selected (0-5)
  - Stock availability
- **User Controls**:
  - `btn[0]`: Move selection left/up
  - `btn[1]`: Move selection right/down
  - `btn[2]`: Decrease quantity (-1, min 0)
  - `btn[3]`: Increase quantity (+1, max 5)
- **Visual Feedback**:
  - Highlight currently selected drink
  - Show total items selected
  - Show total price
- **Transition**: Long press btn[3] or dedicated confirm button → STATE 2 (PAYMENT)

### State 2: PAYMENT (Coin Insertion & Payment)
- **Display Areas**:
  1. **Order Summary**:
     - List of selected drinks and quantities
     - Total amount due
  2. **Payment Section**:
     - Amount paid so far
     - Remaining balance
     - Available coin denominations (1, 5, 10)
  3. **Machine Status**:
     - Available change in machine
     - Transaction status messages
- **User Controls**:
  - `btn[0]`: Move left in coin selection (10 → 5 → 1 → 10...)
  - `btn[1]`: Move right in coin selection (1 → 5 → 10 → 1...)
  - `btn[2]`: Cancel transaction → return to SELECTION
  - `btn[3]`: Insert selected coin denomination
- **Payment Logic**:
  1. User selects coin denomination and presses btn[3]
  2. Amount paid increases by coin value
  3. When amount paid >= total due:
     - Calculate change needed
     - Check if machine can make exact change
     - If YES: proceed to STATE 3 (DISPENSING)
     - If NO: display error, allow user to add different coins or cancel
- **Change Making Algorithm**:
  - Greedy algorithm: use largest coins first
  - Track machine's coin inventory
  - Validate change is possible before accepting payment

### State 3: DISPENSING (Change & Confirmation)
- **Display**:
  - "Dispensing drinks..." animation
  - Change breakdown (number of each coin returned)
  - Transaction summary
- **Actions**:
  1. Update machine coin inventory (add paid coins, subtract change coins)
  2. Update drink stock levels
  3. Animate dispensing process
  4. Display change given
- **LED Indicators**:
  - Blink pattern during dispensing
  - Success indicator when complete
- **Transition**: After 3-5 seconds → return to STATE 0 (IDLE)

### State 4: ERROR (Insufficient Change / Out of Stock)
- **Display error message**:
  - "Cannot make exact change"
  - "Item out of stock"
  - "Please make different selection"
- **User Controls**:
  - `btn[2]`: Return coins, go back to SELECTION
  - `btn[3]`: Try different payment (if change issue)
- **Transition**: User choice → STATE 1 or maintain STATE 2

## Data Structures

### Drink Inventory
```verilog
// 9 drinks, each with:
reg [7:0] drink_stock [8:0];      // Stock count per drink (0-255)
reg [7:0] drink_price [8:0];      // Price per drink (0-255 cents)
reg [2:0] drink_selected [8:0];   // Selected quantity (0-5)
```

### Coin Inventory (Vending Machine)
```verilog
reg [7:0] coin_1_count;   // Number of $1 coins in machine
reg [7:0] coin_5_count;   // Number of $5 coins in machine
reg [7:0] coin_10_count;  // Number of $10 coins in machine
```

### Payment Tracking
```verilog
reg [15:0] total_due;        // Total amount to pay
reg [15:0] amount_paid;      // Amount paid so far
reg [15:0] change_amount;    // Change to return
reg [7:0] change_coins [2:0]; // Change breakdown [1s, 5s, 10s]
```

### Selection Tracking
```verilog
reg [3:0] selected_drink;    // Currently highlighted drink (0-8)
reg [1:0] selected_coin;     // Currently selected coin type (0=1, 1=5, 2=10)
```

## Memory Files

### 1. background.mem
- 320×240 background image for main screen
- 12-bit RGB values (4 bits per channel)
- Size: 76,800 words

### 2. drinks.mem
- 9 drink images, each 48×48 pixels
- Total: 9 × 48 × 48 = 20,736 words
- Each drink sprite stored sequentially

### 3. coins.mem
- Coin images for denominations (1, 5, 10)
- Each coin: 32×32 pixels
- Total: 3 × 32 × 32 = 3,072 words

### 4. numbers.mem
- Digit sprites (0-9) for displaying prices and quantities
- Each digit: 16×24 pixels
- Total: 10 × 16 × 24 = 3,840 words

### 5. ui_elements.mem
- Selection cursor/highlight
- Buttons/icons
- Status indicators
- Estimated: 4,096 words

### Total SRAM Size Required
76,800 + 20,736 + 3,072 + 3,840 + 4,096 = **108,544 words** (18 address bits)

## Display Layout

### Selection Screen (640×480)
```
┌─────────────────────────────────────────┐
│         VENDING MACHINE                 │
├───────────┬───────────┬───────────┐    │
│  Drink 1  │  Drink 2  │  Drink 3  │    │
│  $10      │  $5       │  $15      │    │
│  Qty: 0   │  Qty: 1   │  Qty: 0   │    │
├───────────┼───────────┼───────────┤    │
│  Drink 4  │  Drink 5  │  Drink 6  │    │
│  $8       │  $12      │  $6       │    │
│  Qty: 0   │  Qty: 0   │  Qty: 2   │    │
├───────────┼───────────┼───────────┤    │
│  Drink 7  │  Drink 8  │  Drink 9  │    │
│  $20      │  $10      │  $15      │    │
│  Qty: 0   │  Qty: 0   │  Qty: 0   │    │
└───────────┴───────────┴───────────┘    │
│                                         │
│  Total: 3 items  |  Amount: $27        │
│  [Press BTN3 long to checkout]         │
└─────────────────────────────────────────┘
```

### Payment Screen
```
┌─────────────────────────────────────────┐
│  ORDER SUMMARY:                         │
│  Drink 2 × 1 = $5                       │
│  Drink 6 × 2 = $12                      │
│  ─────────────────                      │
│  TOTAL: $27                             │
│                                         │
│  PAYMENT:                               │
│  Amount Paid: $30                       │
│  Remaining: $0  (Overpaid: $3)          │
│                                         │
│  SELECT COIN:                           │
│  [ $1 ]  [>$5<]  [ $10 ]                │
│                                         │
│  Machine Change Available:              │
│  $1: 50   $5: 20   $10: 15              │
│                                         │
│  [BTN0/1: Select] [BTN3: Insert]        │
│  [BTN2: Cancel]                         │
└─────────────────────────────────────────┘
```

## Button Debouncing

All button inputs must be debounced to prevent:
- Multiple triggers from single press
- Bouncing during state transitions

**Debounce Time**: 20ms (2,000,000 clock cycles @ 100MHz)

## Change Making Algorithm

```
function make_change(change_amount):
  temp_10 = 0, temp_5 = 0, temp_1 = 0
  remaining = change_amount

  // Use $10 coins
  temp_10 = min(remaining / 10, coin_10_count)
  remaining -= temp_10 * 10

  // Use $5 coins
  temp_5 = min(remaining / 5, coin_5_count)
  remaining -= temp_5 * 5

  // Use $1 coins
  temp_1 = min(remaining, coin_1_count)
  remaining -= temp_1

  if remaining == 0:
    return SUCCESS, [temp_1, temp_5, temp_10]
  else:
    return FAIL, cannot make exact change
```

## Initial Configuration

### Drink Prices (Example)
- Drinks 0-2: $10, $5, $15
- Drinks 3-5: $8, $12, $6
- Drinks 6-8: $20, $10, $15

### Initial Stock
- All drinks: 10 units each

### Initial Coin Inventory
- $1 coins: 50
- $5 coins: 20
- $10 coins: 15

## Timing Requirements

- **VGA Pixel Clock**: 25 MHz
- **State Transition**: Debounced button press
- **Animation Frame Rate**: ~30 FPS (update every 833,333 cycles @ 25MHz)
- **Dispensing Animation**: 3 seconds minimum

## Module Hierarchy

```
lab10 (top module)
├── vga_sync (VGA timing generator)
├── clk_divider (100MHz → 50MHz)
├── sram (memory for images)
├── button_debouncer (×4, one per button)
├── fsm_controller (state machine)
├── selection_controller (drink selection logic)
├── payment_controller (payment & change logic)
├── display_controller (VGA pixel generation)
│   ├── background_renderer
│   ├── drink_grid_renderer
│   ├── text_renderer (prices, quantities)
│   └── payment_screen_renderer
└── coin_manager (inventory tracking)
```

## LED Indicators

- `usr_led[0]`: State indicator (blink pattern per state)
- `usr_led[1]`: Payment accepted
- `usr_led[2]`: Transaction in progress
- `usr_led[3]`: Error indicator

## Reset Behavior

On `reset_n` assertion:
- Return to IDLE state
- Clear all selections
- Reset payment counters
- DO NOT reset drink stock or coin inventory (persistent)
- Clear display to background

## Error Conditions

1. **Insufficient Change**: Cannot make exact change with available coins
2. **Out of Stock**: Selected drink quantity exceeds available stock
3. **Overpayment Unresolvable**: Paid too much, cannot return exact change
4. **Invalid State**: Corrupted state machine (should never happen)

## Testing Scenarios

1. **Basic Purchase**: Select 1 drink, pay exact amount
2. **Multiple Items**: Select multiple drinks, pay with various coins
3. **Change Required**: Overpay and receive change
4. **Insufficient Change**: Trigger change-making failure
5. **Stock Depletion**: Attempt to buy more than available
6. **Cancel Transaction**: Cancel during payment phase
7. **Maximum Selection**: Select 5 of same drink (max limit)
8. **Edge Case**: Pay with only $1 coins for expensive item

## Future Enhancements (Optional)

- Touch screen support instead of buttons
- Receipt printing simulation
- Drink temperature indicator
- Maintenance mode for restocking
- Sales statistics tracking
- Multiple language support
