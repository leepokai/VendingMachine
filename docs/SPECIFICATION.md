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

All memory files contain 12-bit RGB values (4 bits per channel) stored as hexadecimal.

### 1. background.mem
- Background image for main screen
- Dimensions: 40 × 70 pixels
- Size: 2,800 words

### 2. drinks.mem
- Drink bottle animation sprites
- Dimensions: 10 × 10 pixels per frame
- Frames: 6 frames per drink (falling/dispensing animation)
- Number of drinks: 9 drink types
- Total: 10 × 10 × 6 × 9 = 5,400 words
- Layout: [Drink0_Frame0...Frame5][Drink1_Frame0...Frame5]...[Drink8_Frame0...Frame5]

### 3. coins.mem
- Coin images for denominations (1, 5, 10 NTD)
- Dimensions: 20 × 20 pixels per coin
- Total: 20 × 20 × 3 = 1,200 words

### 4. bills.mem
- Paper money image (100 NTD bill)
- Dimensions: 20 × 10 pixels
- Total: 200 words

### 5. number.mem
- Digit sprites (0-9) for displaying prices and quantities
- Dimensions: 8 × 16 pixels per digit
- Total: 8 × 16 × 10 = 1,280 words

### 6. character.mem
- Character/text sprites for UI labels
- Dimensions: 8 × 16 pixels per character
- Characters: A-Z, a-z, and common punctuation (~95 characters)
- Total: 8 × 16 × 95 = 12,160 words

### 7. ui_elements.mem
- Selection cursor/highlight indicator
- Dimensions: 25 × 5 pixels
- Total: 125 words

### Total SRAM Size Required
2,800 + 5,400 + 1,200 + 200 + 1,280 + 12,160 + 125 = **23,165 words** (~15 address bits)


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
