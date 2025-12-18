`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: lab10
// Project Name: Vending Machine
// Description: A Vending Machine controller with VGA display
//
// Dependencies: vga_sync, clk_divider, sram
//
//////////////////////////////////////////////////////////////////////////////////
module lab10( 
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] sw,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE 
    );
// Debounced button signals
wire [3:0] btn_debounced; 
wire rst = ~reset_n;
// Instantiate debounce modules for each button
debounce deb0 (.clk(clk), .reset(rst), .btn_in(usr_btn[0]), .btn_out(btn_debounced[0]));
debounce deb1 (.clk(clk), .reset(rst), .btn_in(usr_btn[1]), .btn_out(btn_debounced[1]));
debounce deb2 (.clk(clk), .reset(rst), .btn_in(usr_btn[2]), .btn_out(btn_debounced[2]));
debounce deb3 (.clk(clk), .reset(rst), .btn_in(usr_btn[3]), .btn_out(btn_debounced[3]));
// Edge detection for btn2 (Add to Cart) and btn3 (Submit)
reg btn2_d, btn3_d;
wire btn2_posedge, btn3_posedge;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        btn2_d <= 0;
        btn3_d <= 0;
    end else begin
        btn2_d <= btn_debounced[2];
        btn3_d <= btn_debounced[3];
    end 
end
assign btn2_posedge = btn_debounced[2] && ~btn2_d;
assign btn3_posedge = btn_debounced[3] && ~btn3_d;
// General control signals
wire [11:0] data_in;
wire        sram_we, sram_en;
reg         sram_we_reg;
// Background SRAM signals
wire [11:0] data_out;
reg  [11:0] pixel_addr; // Address for the background SRAM

// Pipeline registers for background AGU timing fix (3-stage)
reg on_background_reg1;
reg on_background_reg2;
reg on_background_reg3;
reg [20:0] scaled_x_stage1;
reg [20:0] scaled_y_stage1;
reg [10:0] scaled_x_stage2;
reg [10:0] scaled_y_stage2;
reg [16:0] y_mult_40_stage2;
// Sprite SRAM signals
wire [11:0] selectbox_data_out;
reg  [6:0]  selectbox_addr; // Address for the sprite SRAM
// ------------------------------------------------------------------------
// Main FSM (SELECTION <-> PAYMENT states)
// ------------------------------------------------------------------------
wire current_state;  // 0=SELECTION, 1=PAYMENT
reg prev_state;       // Previous state for transition detection
main_fsm main_state_machine (
    .clk(clk),
    .reset(rst),
    .btn_confirm(btn_debounced[3]),
    .dispensing(dispensing),
    .dispense_done(dispense_completed),
    .current_state(current_state)
);
// State transition detection
wire transition_to_selection = (prev_state == 1'b1) && (current_state == 1'b0);
always @(posedge clk or posedge rst) begin
    if (rst)
        prev_state <= 1'b0;
    else
        prev_state <= current_state;
end
// ------------------------------------------------------------------------
// Drink Selection FSM (for SELECTION state)
// ------------------------------------------------------------------------
wire [3:0] selection_index;
vending_fsm fsm0 (
    .clk(clk),
    .reset(rst || transition_to_selection),
    .btn_left(btn_debounced[1]),
    .btn_right(btn_debounced[0]),
    .selection_index(selection_index)
);
// ------------------------------------------------------------------------
// Coin Selection FSM (for PAYMENT state)
// ------------------------------------------------------------------------
wire [1:0] coin_index;  // 0=$1, 1=$5, 2=$10
coin_selector coin_sel0 (
    .clk(clk),
    .reset(rst),
    .btn_up(btn_debounced[1]),      // btn1 - move up (Previous)
    .btn_down(btn_debounced[0]),    // btn0 - move down (Next)
    .coin_index(coin_index)
);
// ------------------------------------------------------------------------
// Refund & Cancellation Logic
// ------------------------------------------------------------------------
reg refund_mode; // 1 = Refunding (Purchase Amount = 0), 0 = Normal Purchase
reg refund_reason; // 0 = Manual Refund, 1 = Dispenser Failed/No Change
reg [27:0] refund_msg_timer; // Timer for displaying the refund message
wire refund_msg_active = (refund_msg_timer > 0);

// Cancel Request Logic (Long press btn0 & btn1 for ~1.5s)
reg [27:0] cancel_counter;
wire cancel_trigger;
always @(posedge clk or posedge rst) begin
    if (rst) cancel_counter <= 28'd0;
    else if (current_state == 1'b1 && btn_debounced[0] && btn_debounced[1]) begin
        if (cancel_counter < 28'd150_000_000)
            cancel_counter <= cancel_counter + 1;
    end else begin
        cancel_counter <= 28'd0;
    end
end
assign cancel_trigger = (cancel_counter == 28'd150_000_000);

// Refund Message Timer Logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        refund_msg_timer <= 0;
    end else begin
        if (refund_msg_timer > 0)
            refund_msg_timer <= refund_msg_timer - 1;
        
        // Start timer on triggers (handled in the main always block via flags, 
        // but can also be redundant set here for robustness or handled purely in the state machine)
    end
end

// Price Calculation
wire [15:0] total_due;  // Total amount to pay based on cart
price_calculator price_calc0 (
    .clk(clk),
    .reset(rst),
    // Price inputs
    .price_0(drink_price[0]), .price_1(drink_price[1]), .price_2(drink_price[2]),
    .price_3(drink_price[3]), .price_4(drink_price[4]), .price_5(drink_price[5]),
    .price_6(drink_price[6]), .price_7(drink_price[7]), .price_8(drink_price[8]),
    // Cart quantity inputs
    .qty_0(cart_quantity[0]), .qty_1(cart_quantity[1]), .qty_2(cart_quantity[2]),
    .qty_3(cart_quantity[3]), .qty_4(cart_quantity[4]), .qty_5(cart_quantity[5]),
    .qty_6(cart_quantity[6]), .qty_7(cart_quantity[7]), .qty_8(cart_quantity[8]),
    // Output
    .total_due(total_due)
);
// Paid Amount Calculation
wire [15:0] paid_amount;  // Total amount paid via coins
paid_calculator paid_calc0 (
    .clk(clk),
    .reset(rst),
    .coin1_count(coins_inserted[0]),
    .coin5_count(coins_inserted[1]),
    .coin10_count(coins_inserted[2]),
    .coin100_count(coins_inserted[3]),
    .paid_amount(paid_amount)
);
// ------------------------------------------------------------------------
// Payment Status & Change Calculation
// ------------------------------------------------------------------------
reg payment_sufficient;     // Flag: paid_amount >= total_due
reg [15:0] change_amount;   // Change to return
always @(posedge clk or posedge rst) begin
    if (rst) begin
        payment_sufficient <= 1'b0;
        change_amount <= 16'd0;
    end else begin
        // Check if payment is sufficient
        if (paid_amount >= total_due) begin
            payment_sufficient <= 1'b1;
            change_amount <= paid_amount - total_due;
        end else begin
            payment_sufficient <= 1'b0;
            change_amount <= 16'd0;
        end
    end
end
// ------------------------------------------------------------------------
// Change Dispenser (calculates coin dispensing using greedy algorithm)
// ------------------------------------------------------------------------
reg dispenser_start;                      // Trigger signal for dispenser
wire [7:0] dispense_coin1_wire;           // $1 coins to dispense
wire [7:0] dispense_coin5_wire;           // $5 coins to dispense
wire [7:0] dispense_coin10_wire;          // $10 coins to dispense
wire [7:0] dispense_coin100_wire;         // $100 coins to dispense
wire dispenser_done;                      // Dispenser calculation complete
wire dispenser_success;                   // Exact change possible
change_dispenser change_disp0 (
    .clk(clk),
    .reset(rst),
    .start(dispenser_start),
    .change_amount(change_amount),
    .avail_coin1(avail_coins[0] + coins_inserted[0]),
    .avail_coin5(avail_coins[1] + coins_inserted[1]),
    .avail_coin10(avail_coins[2] + coins_inserted[2]),
    .avail_coin100(avail_coins[3] + coins_inserted[3]),
    .dispense_coin1(dispense_coin1_wire),
    .dispense_coin5(dispense_coin5_wire),
    .dispense_coin10(dispense_coin10_wire),
    .dispense_coin100(dispense_coin100_wire),
    .done(dispenser_done),
    .success(dispenser_success)
);
// Dispensing state management and coin insertion logic
// NOTE: Merged into one always block to avoid multiple driver errors
reg dispensing;                           // Currently dispensing change
reg dispense_completed;                   // Flag: dispensing has completed
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dispenser_start <= 1'b0;
        dispensing <= 1'b0;
        dispense_completed <= 1'b0;
        refund_mode <= 1'b0;
        refund_reason <= 1'b0;
        dispensed_coins[0] <= 8'd0;
        dispensed_coins[1] <= 8'd0;
        dispensed_coins[2] <= 8'd0;
        dispensed_coins[3] <= 8'd0;
        coins_inserted[0] <= 8'd0;
        coins_inserted[1] <= 8'd0;
        coins_inserted[2] <= 8'd0;
        coins_inserted[3] <= 8'd0;
        // Reset coin inventory to initial values
        avail_coins[0] <= 8'd10;  // 10 x $1 coins
        avail_coins[1] <= 8'd10;  // 10 x $5 coins
        avail_coins[2] <= 8'd10;  // 10 x $10 coins
        avail_coins[3] <= 8'd5;   // 5 x $100 bills (example)
        // Reset stock to initial values
        stock[0] <= 5; stock[1] <= 0; stock[2] <= 0;
        stock[3] <= 5; stock[4] <= 5; stock[5] <= 0;
        stock[6] <= 0; stock[7] <= 0; stock[8] <= 5;
    end else begin
        // Default: don't start dispenser
        dispenser_start <= 1'b0;
        // Priority 0: Reset for new round when returning to SELECTION
        if (transition_to_selection) begin
            dispense_completed <= 1'b0;
            refund_mode <= 1'b0; // Reset refund mode
            dispensed_coins[0] <= 8'd0;
            dispensed_coins[1] <= 8'd0;
            dispensed_coins[2] <= 8'd0;
            dispensed_coins[3] <= 8'd0;
            coins_inserted[0] <= 8'd0;
            coins_inserted[1] <= 8'd0;
            coins_inserted[2] <= 8'd0;
            coins_inserted[3] <= 8'd0;
        // Priority 1: When dispensing is done, update inventories and reset coins
        end else if (dispensing && dispenser_done) begin
            if (dispenser_success) begin
                // Update available coins: subtract dispensed, add inserted
                avail_coins[0] <= avail_coins[0] - dispense_coin1_wire + coins_inserted[0];
                avail_coins[1] <= avail_coins[1] - dispense_coin5_wire + coins_inserted[1];
                avail_coins[2] <= avail_coins[2] - dispense_coin10_wire + coins_inserted[2];
                avail_coins[3] <= avail_coins[3] - dispense_coin100_wire + coins_inserted[3];
                
                // Update stock: decrease by cart quantities ONLY if NOT REFUND mode
                if (!refund_mode) begin
                    stock[0] <= stock[0] - cart_quantity[0];
                    stock[1] <= stock[1] - cart_quantity[1];
                    stock[2] <= stock[2] - cart_quantity[2];
                    stock[3] <= stock[3] - cart_quantity[3];
                    stock[4] <= stock[4] - cart_quantity[4];
                    stock[5] <= stock[5] - cart_quantity[5];
                    stock[6] <= stock[6] - cart_quantity[6];
                    stock[7] <= stock[7] - cart_quantity[7];
                    stock[8] <= stock[8] - cart_quantity[8];
                end

                // Store dispensed amounts for display
                dispensed_coins[0] <= dispense_coin1_wire;
                dispensed_coins[1] <= dispense_coin5_wire;
                dispensed_coins[2] <= dispense_coin10_wire;
                dispensed_coins[3] <= dispense_coin100_wire;
                
                // Reset inserted coins (Moved to transition_to_selection block)
                
                // Mark dispensing as completed
                dispense_completed <= 1'b1;
            end else begin
                // Dispenser Failed (Insufficient Change)
                // Trigger REFUND MODE automatically to return all money
                refund_mode <= 1'b1;
                refund_reason <= 1'b1; // Reason: Failed
                refund_msg_timer <= 28'd500_000_000; // Show "FAILED" for 5 seconds
                dispenser_start <= 1'b1; // Restart dispenser with new mode
                // Do NOT set dispense_completed, we are retrying
            end
            dispensing <= 1'b0;

        // Priority 2: Cancel Trigger (Manual Refund)
        end else if (cancel_trigger && !dispensing && !dispense_completed) begin
            refund_mode <= 1'b1;
            refund_reason <= 1'b0; // Reason: Manual
            refund_msg_timer <= 28'd500_000_000; // Show "REFUND" for 5 seconds
            // Cart quantity clearing is handled in the Cart Update Logic block
            
        // Priority 2.5: Start Dispenser in Refund Mode (Delayed Start)
        end else if (refund_mode && !dispensing && !dispense_completed && !dispenser_start) begin
             dispenser_start <= 1'b1;
             dispensing <= 1'b1;

        // Priority 3: Start dispensing when btn3 pressed in PAYMENT with sufficient payment
        end else if (current_state == 1'b1 && btn3_posedge && payment_sufficient && !dispensing && !dispense_completed) begin
            dispenser_start <= 1'b1;
            dispensing <= 1'b1;
        // Priority 4: Coin insertion in PAYMENT state
        end else if (current_state == 1'b1 && btn2_posedge && !dispensing && !dispense_completed) begin
            // Insert one of the selected coin type
            coins_inserted[coin_index] <= coins_inserted[coin_index] + 8'd1;
        end
    end
end
// ------------------------------------------------------------------------
// Stock & Cart Management
// ------------------------------------------------------------------------
reg [2:0] stock [0:8];         // Available stock for each item
reg [2:0] cart_quantity [0:8]; // Items selected by user (the "shopping cart")
reg [7:0] drink_price [0:8];   // Price for each drink (in dollars)
// ------------------------------------------------------------------------
// Coin Tracking (for PAYMENT state)
// ------------------------------------------------------------------------
reg [7:0] coins_inserted [0:3]; // Number of each coin type inserted
                                 // [0]=$1, [1]=$5, [2]=$10, [3]=$100
reg [7:0] avail_coins [0:3];     // Machine's available coins for change
                                 // [0]=$1, [1]=$5, [2]=$10, [3]=$100
reg [7:0] dispensed_coins [0:3]; // Coins to be dispensed as change
                                 // [0]=$1, [1]=$5, [2]=$10, [3]=$100
integer i;
initial begin
    // Initialize stock as per user request
    stock[0] = 5; stock[1] = 0; stock[2] = 0;
    stock[3] = 5; stock[4] = 5; stock[5] = 0;
    stock[6] = 0; stock[7] = 0; stock[8] = 5;
    // Initialize prices (as per SPECIFICATION.md example)
    drink_price[0] = 10; drink_price[1] = 0;  drink_price[2] = 0;
    drink_price[3] = 8;  drink_price[4] = 12; drink_price[5] = 0;
    drink_price[6] = 0; drink_price[7] = 0; drink_price[8] = 15;
    // Initialize cart to all zeros
    for (i = 0; i < 9; i = i + 1) begin
        cart_quantity[i] = 0;
    end
    // Initialize coins inserted to zero
    coins_inserted[0] = 0;
    coins_inserted[1] = 0;
    coins_inserted[2] = 0;
    coins_inserted[3] = 0;
    // Initialize machine's coin inventory (AVAIL)
    avail_coins[0] = 10;  // 10 x $1 coins
    avail_coins[1] = 10;  // 10 x $5 coins
    avail_coins[2] = 10;  // 10 x $10 coins
    avail_coins[3] = 5;   // 5 x $100 bills
    // Initialize dispensed coins to zero
    dispensed_coins[0] = 0;
    dispensed_coins[1] = 0;
    dispensed_coins[2] = 0;
    dispensed_coins[3] = 0;
end
// Cart update logic (SELECTION state only)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset cart on system reset
        cart_quantity[0] <= 0; cart_quantity[1] <= 0; cart_quantity[2] <= 0;
        cart_quantity[3] <= 0; cart_quantity[4] <= 0; cart_quantity[5] <= 0;
        cart_quantity[6] <= 0; cart_quantity[7] <= 0; cart_quantity[8] <= 0;
    end else begin
        // Reset cart when returning from PAYMENT to SELECTION (new round)
        if (transition_to_selection) begin
            cart_quantity[0] <= 0; cart_quantity[1] <= 0; cart_quantity[2] <= 0;
            cart_quantity[3] <= 0; cart_quantity[4] <= 0; cart_quantity[5] <= 0;
            cart_quantity[6] <= 0; cart_quantity[7] <= 0; cart_quantity[8] <= 0;
        // Reset cart immediately when Refund is triggered (Manual or Auto)
        // This ensures total_due becomes 0, so change_amount becomes paid_amount
        end else if (cancel_trigger || (!dispenser_success && dispensing && dispenser_done)) begin
            cart_quantity[0] <= 0; cart_quantity[1] <= 0; cart_quantity[2] <= 0;
            cart_quantity[3] <= 0; cart_quantity[4] <= 0; cart_quantity[5] <= 0;
            cart_quantity[6] <= 0; cart_quantity[7] <= 0; cart_quantity[8] <= 0;
        end else if (current_state == 1'b0 && btn2_posedge) begin
            // SELECTION state: On btn2 press, cycle the cart quantity for the selected item
            if (cart_quantity[selection_index] >= stock[selection_index]) begin
                cart_quantity[selection_index] <= 0;
            end else begin
                cart_quantity[selection_index] <= cart_quantity[selection_index] + 1;
            end
        end
    end
end
// NOTE: Coin insertion logic moved to dispensing block above to avoid multiple drivers
// ------------------------------------------------------------------------
// Display & Image Parameters
// ------------------------------------------------------------------------
// Source image sizes
localparam VBUF_W = 40; // video buffer width
localparam VBUF_H = 70; // video buffer height
localparam BOX_W  = 25; // selection box width
localparam BOX_H  = 5;  // selection box height
// VGA & Scaling parameters
localparam VGA_W = 640;
localparam VGA_H = 480;
localparam SCALE_FACTOR = 6;
localparam SCALED_IMG_W = VBUF_W * SCALE_FACTOR; // 40 * 6 = 240
localparam SCALED_IMG_H = VBUF_H * SCALE_FACTOR; // 70 * 6 = 420
// Centering calculations
localparam H_START = (VGA_W - SCALED_IMG_W) / 2; // (640 - 240) / 2 = 200
localparam H_END   = H_START + SCALED_IMG_W - 1;
localparam V_START = (VGA_H - SCALED_IMG_H) / 2; // (480 - 420) / 2 = 30
localparam V_END   = V_START + SCALED_IMG_H - 1;
// Sprite parameters
localparam TRANSPARENT_COLOR = 12'h0F0; // Green screen color
reg [9:0] sprite_x_start, sprite_y_start;
reg [5:0] base_x, base_y;
reg [9:0] on_screen_center_x, on_screen_center_y;
// Coin display parameters (20x20 pixels source, scaled to 30x30)
localparam COIN_W = 30;
localparam COIN_H = 30;
localparam COIN_X_START = 480;   // Right side of screen
localparam COIN_Y_SPACING = 95;  // Vertical spacing between coins
localparam COIN_Y_BASE = 60;     // Start Y position for first coin
// Coin positions (3 coins + 1 bill vertically arranged with text below)
// Coin 0 ($1):  X=480, Y=60
// Coin 1 ($5):  X=480, Y=155
// Coin 2 ($10): X=480, Y=250
// Coin 3 ($100): X=480, Y=345
wire [9:0] coin0_x_start = COIN_X_START;
wire [9:0] coin0_y_start = COIN_Y_BASE;
wire [9:0] coin1_x_start = COIN_X_START;
wire [9:0] coin1_y_start = COIN_Y_BASE + COIN_Y_SPACING;
wire [9:0] coin2_x_start = COIN_X_START;
wire [9:0] coin2_y_start = COIN_Y_BASE + COIN_Y_SPACING * 2;
wire [9:0] coin3_x_start = COIN_X_START;
wire [9:0] coin3_y_start = COIN_Y_BASE + COIN_Y_SPACING * 3;
// Coin selection box position (based on coin_index)
reg [9:0] coin_selectbox_x, coin_selectbox_y;
// ------------------------------------------------------------------------
// VGA and Clock Instantiation
// ------------------------------------------------------------------------
// General VGA control signals
wire vga_clk;
wire video_on;
wire pixel_tick;
wire [9:0] pixel_x;
wire [9:0] pixel_y;
reg  [11:0] rgb_reg;
reg  [11:0] rgb_next;
vga_sync vs0(
  .clk(vga_clk), .reset(rst), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);
clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(rst),
  .clk_out(vga_clk)
);

// --- GLOBAL PIXEL PIPELINE ---
// Synchronize VGA coordinates to 100MHz clock domain for safe AGU usage
reg [9:0] pixel_x_core, pixel_y_core;
always @(posedge clk) begin
    pixel_x_core <= pixel_x;
    pixel_y_core <= pixel_y;
end

// ------------------------------------------------------------------------
// Text Renderer (displays "TOTAL: $XXX" in top-left corner)
// ------------------------------------------------------------------------
wire text_pixel;
wire is_text_area;
text_renderer text_render0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .total_due(total_due),
  .text_pixel(text_pixel),
  .is_text_area(is_text_area)
);
// ------------------------------------------------------------------------
// Paid Text Renderer (displays "PAID: $XXX" below TOTAL)
// ------------------------------------------------------------------------
wire paid_text_pixel;
wire is_paid_text_area;
paid_text_renderer paid_text_render0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .paid_amount(paid_amount),
  .text_pixel(paid_text_pixel),
  .is_text_area(is_paid_text_area)
);
// ------------------------------------------------------------------------
// Change Text Renderer (displays "CHANGE: $XXX" below PAID)
// Displays in both SELECTION and PAYMENT states
// ------------------------------------------------------------------------
wire change_text_pixel;
wire is_change_text_area;
change_text_renderer change_text_render0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .change_amount(change_amount),
  .text_pixel(change_text_pixel),
  .is_text_area(is_change_text_area)
);
// ------------------------------------------------------------------------
// Available Change Display (Overlay on sw[0])
// ------------------------------------------------------------------------
wire [11:0] avail_change_rgb;
wire is_avail_change_active;
available_change_display avail_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .avail1_count(avail_coins[0]),
  .avail5_count(avail_coins[1]),
  .avail10_count(avail_coins[2]),
  .avail100_count(avail_coins[3]),
  .rgb_out(avail_change_rgb),
  .is_drawing(is_avail_change_active)
);

// ------------------------------------------------------------------------
// Help Display (Sw1 to toggle)
// ------------------------------------------------------------------------
wire [11:0] help_rgb;
wire is_help_active;
help_display help_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .show_help(!sw[1]), // Sw1 toggles body (Active Low)
  .rgb_out(help_rgb),
  .is_drawing(is_help_active)
);

// ------------------------------------------------------------------------
// Coin Count Display (displays count below each coin)
// NOTE: Passing raw pixel_x because module has internal registers
// ------------------------------------------------------------------------
wire coin_text_pixel;
wire is_coin_text_area;
coin_count_display coin_count_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x),
  .pixel_y(pixel_y),
  .coin0_y_start(coin0_y_start),
  .coin1_y_start(coin1_y_start),
  .coin2_y_start(coin2_y_start),
  .coin3_y_start(coin3_y_start),
  .coin1_count(coins_inserted[0]),
  .coin5_count(coins_inserted[1]),
  .coin10_count(coins_inserted[2]),
  .coin100_count(coins_inserted[3]),
  .text_pixel(coin_text_pixel),
  .is_coin_text_area(is_coin_text_area)
);
// ------------------------------------------------------------------------
// Dispensed Change Display (shows list on left after payment)
// ------------------------------------------------------------------------
wire [11:0] disp_change_rgb;
wire is_disp_change_active;
dispensed_change_display disp_change_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .disp1_count(dispensed_coins[0]),
  .disp5_count(dispensed_coins[1]),
  .disp10_count(dispensed_coins[2]),
  .disp100_count(dispensed_coins[3]),
  .rgb_out(disp_change_rgb),
  .is_drawing(is_disp_change_active)
);
// ------------------------------------------------------------------------
// Item Price Display (displays "$XX" above each item)
// ------------------------------------------------------------------------
wire price_text_pixel;
wire is_price_text_area;
item_price_display price_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x_core),
  .pixel_y(pixel_y_core),
  .price_0(drink_price[0]), .price_1(drink_price[1]), .price_2(drink_price[2]),
  .price_3(drink_price[3]), .price_4(drink_price[4]), .price_5(drink_price[5]),
  .price_6(drink_price[6]), .price_7(drink_price[7]), .price_8(drink_price[8]),
  .text_pixel(price_text_pixel),
  .is_text_area(is_price_text_area)
);

// ------------------------------------------------------------------------
// Refund Text Renderer (displays "REFUND" or "FAILED" in exit area)
// ------------------------------------------------------------------------
wire refund_text_pixel;
wire is_refund_text_area;
refund_text_renderer refund_render0 (
    .clk(clk),
    .reset(rst),
    .pixel_x(pixel_x_core),
    .pixel_y(pixel_y_core),
    .refund_active(refund_msg_active),
    .refund_reason(refund_reason),
    .text_pixel(refund_text_pixel),
    .is_text_area(is_refund_text_area)
);

// ------------------------------------------------------------------------
// SRAM Blocks for Background and Sprites
// ------------------------------------------------------------------------
// SRAM for Background Image
sram #(
    .DATA_WIDTH(12), 
    .ADDR_WIDTH(12), 
    .RAM_SIZE(VBUF_W*VBUF_H),
    .MEM_INIT_FILE("VendingMachineBg.mem")
) ram0 (
    .clk(clk), 
    .we(sram_we), 
    .en(sram_en),
    .addr(pixel_addr), 
    .data_i(data_in), 
    .data_o(data_out)
);
// SRAM for SelectBox sprite
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(7), // 2^7 = 128, enough for 25*5=125 pixels
    .RAM_SIZE(125),
    .MEM_INIT_FILE("SelectBox.mem")
) ram_selectbox (
    .clk(clk),
    .we(1'b0), // Read-only
    .en(1'b1), // Always enabled
    .addr(selectbox_addr),
    .data_i(12'h000),
    .data_o(selectbox_data_out)
);
// SRAM for Green Background Sprite
localparam GREEN_BG_W = 22;
localparam GREEN_BG_H = 5;
wire [11:0] green_bg_data_out;
reg [6:0] green_bg_addr; // 2^7=128, for 22*5=110 pixels
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(7),
    .RAM_SIZE(GREEN_BG_W * GREEN_BG_H),
    .MEM_INIT_FILE("VendingMachineGreenBgsBg.mem")
) ram_green_bg (
    .clk(clk),
    .we(1'b0), // Read-only
    .en(1'b1), // Always enabled
    .addr(green_bg_addr),
    .data_i(12'h000),
    .data_o(green_bg_data_out)
);
// ------------------------------------------------------------------------
// Coin SRAM modules (20x20 pixels each, except 100 which is 20x10)
// ------------------------------------------------------------------------
wire [11:0] coin1_data_out, coin5_data_out, coin10_data_out, coin100_data_out;
reg [8:0] coin_addr;  // 9 bits for 400 pixels (20x20) - fits 20x10 (200) too
// $1 Coin SRAM
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(9),
    .RAM_SIZE(400),     // 20 * 20
    .MEM_INIT_FILE("Coin1.mem")
) ram_coin1 (
    .clk(clk),
    .we(1'b0),
    .en(1'b1),
    .addr(coin_addr),
    .data_i(12'h000),
    .data_o(coin1_data_out)
);
// $5 Coin SRAM
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(9),
    .RAM_SIZE(400),
    .MEM_INIT_FILE("Coin5.mem")
) ram_coin5 (
    .clk(clk),
    .we(1'b0),
    .en(1'b1),
    .addr(coin_addr),
    .data_i(12'h000),
    .data_o(coin5_data_out)
);
// $10 Coin SRAM
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(9),
    .RAM_SIZE(400),
    .MEM_INIT_FILE("Coin10.mem")
) ram_coin10 (
    .clk(clk),
    .we(1'b0),
    .en(1'b1),
    .addr(coin_addr),
    .data_i(12'h000),
    .data_o(coin10_data_out)
);
// $100 Bill SRAM (20x10)
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(9),
    .RAM_SIZE(200),
    .MEM_INIT_FILE("Dollar100.mem")
) ram_coin100 (
    .clk(clk),
    .we(1'b0),
    .en(1'b1),
    .addr(coin_addr),
    .data_i(12'h000),
    .data_o(coin100_data_out)
);

// ------------------------------------------------------------------------
// Animation Controller and SRAMs
// ------------------------------------------------------------------------
wire animation_active;
wire [2:0] anim_frame_index;
wire [3:0] anim_item_index; // Index of the item currently being animated
wire [11:0] water_anim_data_out, juice_anim_data_out, tea_anim_data_out, cola_anim_data_out;
reg [9:0] anim_addr; // 10 bits for 10*10*6 = 600 pixels

// Flatten cart quantity for the animator module
wire [26:0] flat_cart_quantity;
assign flat_cart_quantity = {
    cart_quantity[8], cart_quantity[7], cart_quantity[6],
    cart_quantity[5], cart_quantity[4], cart_quantity[3],
    cart_quantity[2], cart_quantity[1], cart_quantity[0]
};

animation_controller anim_manager0 (
    .clk(clk),
    .reset(rst),
    .start(dispenser_success && !refund_mode),
    .flat_cart_quantity(flat_cart_quantity),
    .animation_active(animation_active),
    .frame_index(anim_frame_index),
    .current_item_index(anim_item_index)
);

// SRAM for Water Drop Animation
sram #( .DATA_WIDTH(12), .ADDR_WIDTH(10), .RAM_SIZE(600), .MEM_INIT_FILE("WaterDropSheet.mem") )
ram_anim_water (.clk(clk), .we(1'b0), .en(1'b1), .addr(anim_addr), .data_i(12'h000), .data_o(water_anim_data_out));

// SRAM for Juice Drop Animation
sram #( .DATA_WIDTH(12), .ADDR_WIDTH(10), .RAM_SIZE(600), .MEM_INIT_FILE("JuiceDropSheet.mem") )
ram_anim_juice (.clk(clk), .we(1'b0), .en(1'b1), .addr(anim_addr), .data_i(12'h000), .data_o(juice_anim_data_out));

// SRAM for Tea Drop Animation
sram #( .DATA_WIDTH(12), .ADDR_WIDTH(10), .RAM_SIZE(600), .MEM_INIT_FILE("TeaDropSheet.mem") )
ram_anim_tea (.clk(clk), .we(1'b0), .en(1'b1), .addr(anim_addr), .data_i(12'h000), .data_o(tea_anim_data_out));

// SRAM for Cola Drop Animation
sram #( .DATA_WIDTH(12), .ADDR_WIDTH(10), .RAM_SIZE(600), .MEM_INIT_FILE("ColaDropSheet.mem") )
ram_anim_cola (.clk(clk), .we(1'b0), .en(1'b1), .addr(anim_addr), .data_i(12'h000), .data_o(cola_anim_data_out));

// Tie off unused/static signals
assign usr_led[3:0] = total_due[3:0];
assign sram_we = sram_we_reg;
assign sram_en = 1;
assign data_in = 12'h000;
always @(posedge clk or posedge rst) begin
    if (rst) sram_we_reg <= 1'b0;
    else sram_we_reg <= 1'b0;
end

// ------------------------------------------------------------------------
// Sprite and AGU (Address Generation Unit) Logic
// ------------------------------------------------------------------------
localparam SPRITE_SCALE_FACTOR = 2;

always @(*)
begin
    case (selection_index)
        0: begin base_x = 10; base_y = 14; end
        1: begin base_x = 20; base_y = 14; end
        2: begin base_x = 30; base_y = 14; end
        3: begin base_x = 10; base_y = 26; end
        4: begin base_x = 20; base_y = 26; end
        5: begin base_x = 30; base_y = 26; end
        6: begin base_x = 10; base_y = 37; end
        7: begin base_x = 20; base_y = 37; end
        8: begin base_x = 30; base_y = 37; end
        default: begin base_x = 10; base_y = 14; end
    endcase
    on_screen_center_x = H_START + base_x * SCALE_FACTOR;
    on_screen_center_y = V_START + base_y * SCALE_FACTOR;
    sprite_x_start = on_screen_center_x - (BOX_W * SPRITE_SCALE_FACTOR / 2);
    sprite_y_start = on_screen_center_y - (BOX_H * SPRITE_SCALE_FACTOR / 2);
end

// AGU for the background image (3-stage pipeline to fix timing)
// NOTE: Use pixel_x_core which is 1 cycle delayed.
always @(posedge clk) begin
    on_background_reg1 <= (pixel_x_core >= H_START && pixel_x_core <= H_END) && (pixel_y_core >= V_START && pixel_y_core <= V_END);
    if ((pixel_x_core >= H_START && pixel_x_core <= H_END) && (pixel_y_core >= V_START && pixel_y_core <= V_END)) begin
        scaled_x_stage1 <= (pixel_x_core - H_START) * 171;
        scaled_y_stage1 <= (pixel_y_core - V_START) * 171;
    end
end
always @(posedge clk) begin
    on_background_reg2 <= on_background_reg1;
    on_background_reg3 <= on_background_reg2;
    if (on_background_reg1) begin
        scaled_x_stage2 <= scaled_x_stage1 >> 10;
        scaled_y_stage2 <= scaled_y_stage1 >> 10;
        y_mult_40_stage2 <= (scaled_y_stage1 >> 10) * VBUF_W;
    end
end
always @(posedge clk) begin
    if (rst) pixel_addr <= 0;
    else if (on_background_reg2) pixel_addr <= y_mult_40_stage2 + scaled_x_stage2;
    else pixel_addr <= 0;
end

// AGU for the SelectBox sprite (scaled 2x)
wire [9:0] scaled_sprite_w = BOX_W * SPRITE_SCALE_FACTOR;
wire [9:0] scaled_sprite_h = BOX_H * SPRITE_SCALE_FACTOR;
// Use pixel_x_core for calculation to match Background latency domain (100MHz)
wire is_on_sprite = (pixel_x_core >= sprite_x_start) && (pixel_x_core < sprite_x_start + scaled_sprite_w) &&
                    (pixel_y_core >= sprite_y_start) && (pixel_y_core < sprite_y_start + scaled_sprite_h);
always @ (posedge clk) begin
    if (rst) selectbox_addr <= 0;
    else if (is_on_sprite) selectbox_addr <= ((pixel_y_core - sprite_y_start) / SPRITE_SCALE_FACTOR) * BOX_W + ((pixel_x_core - sprite_x_start) / SPRITE_SCALE_FACTOR);
    else selectbox_addr <= 0;
end
// AGU for the Green Background sprite (pipelined)
localparam GREEN_BG_X_START = 9;
localparam GREEN_BG_Y_START = 56;
// wire on_background ... not used here effectively as reg logic handles it
reg is_on_green_bg_reg;
reg is_on_green_bg_reg_s3;
always @(posedge clk) begin
    if (rst) begin
        green_bg_addr <= 0;
        is_on_green_bg_reg <= 1'b0;
        is_on_green_bg_reg_s3 <= 1'b0;
    end else begin
        is_on_green_bg_reg_s3 <= is_on_green_bg_reg;
        // Use stage2 coords which are derived from pixel_x_core logic
        if (on_background_reg2 && (scaled_x_stage2 >= GREEN_BG_X_START) && (scaled_x_stage2 < GREEN_BG_X_START + GREEN_BG_W) && (scaled_y_stage2 >= GREEN_BG_Y_START) && (scaled_y_stage2 < GREEN_BG_Y_START + GREEN_BG_H))
        begin
            is_on_green_bg_reg <= 1'b1;
            green_bg_addr <= (scaled_y_stage2 - GREEN_BG_Y_START) * GREEN_BG_W + (scaled_x_stage2 - GREEN_BG_X_START);
        end else begin
            is_on_green_bg_reg <= 1'b0;
            green_bg_addr <= 0;
        end
    end
end
// AGU and MUX for Animation
localparam ANIM_W = 10;
localparam ANIM_H = 10;
localparam ANIM_SCALE = 6;
localparam SCALED_ANIM_W = ANIM_W * ANIM_SCALE;
localparam SCALED_ANIM_H = ANIM_H * ANIM_SCALE;
localparam ANIM_X_START = (VGA_W - SCALED_ANIM_W) / 2;
localparam ANIM_Y_START = V_START + (GREEN_BG_Y_START + GREEN_BG_H) * SCALE_FACTOR - SCALED_ANIM_H;
// Use pixel_x_core
wire is_on_animation = (pixel_x_core >= ANIM_X_START) && (pixel_x_core < ANIM_X_START + SCALED_ANIM_W) && (pixel_y_core >= ANIM_Y_START) && (pixel_y_core < ANIM_Y_START + SCALED_ANIM_H);
wire [3:0] unscaled_x = (pixel_x_core - ANIM_X_START) / ANIM_SCALE;
wire [3:0] unscaled_y = (pixel_y_core - ANIM_Y_START) / ANIM_SCALE;
always @(posedge clk) begin
    if (rst) begin
        anim_addr <= 0;
    end else if (is_on_animation) begin
        // Corrected AGU for a 10x60 vertical sprite sheet
        anim_addr <= (anim_frame_index * ANIM_H + unscaled_y) * ANIM_W + unscaled_x;
    end else begin
        anim_addr <= 0;
    end
end
reg [11:0] anim_pixel_data;
always @(*)
begin
    case (anim_item_index)
        4'd0: anim_pixel_data = water_anim_data_out;
        4'd3: anim_pixel_data = juice_anim_data_out;
        4'd4: anim_pixel_data = tea_anim_data_out;
        4'd8: anim_pixel_data = cola_anim_data_out;
        default: anim_pixel_data = 12'h000;
    endcase
end
// AGU and Display Logic for Coins
// Function for 1.5x scaling (mapping 0..29 -> 0..19) to fix timing
function [4:0] scale_2_3;
    input [4:0] val;
    begin
        case (val)
            5'd0: scale_2_3 = 5'd0; 5'd1: scale_2_3 = 5'd0; 5'd2: scale_2_3 = 5'd1; 5'd3: scale_2_3 = 5'd2;
            5'd4: scale_2_3 = 5'd2; 5'd5: scale_2_3 = 5'd3; 5'd6: scale_2_3 = 5'd4; 5'd7: scale_2_3 = 5'd4;
            5'd8: scale_2_3 = 5'd5; 5'd9: scale_2_3 = 5'd6; 5'd10: scale_2_3 = 5'd6; 5'd11: scale_2_3 = 5'd7;
            5'd12: scale_2_3 = 5'd8; 5'd13: scale_2_3 = 5'd8; 5'd14: scale_2_3 = 5'd9; 5'd15: scale_2_3 = 5'd10;
            5'd16: scale_2_3 = 5'd10; 5'd17: scale_2_3 = 5'd11; 5'd18: scale_2_3 = 5'd12; 5'd19: scale_2_3 = 5'd12;
            5'd20: scale_2_3 = 5'd13; 5'd21: scale_2_3 = 5'd14; 5'd22: scale_2_3 = 5'd14; 5'd23: scale_2_3 = 5'd15;
            5'd24: scale_2_3 = 5'd16; 5'd25: scale_2_3 = 5'd16; 5'd26: scale_2_3 = 5'd17; 5'd27: scale_2_3 = 5'd18;
            5'd28: scale_2_3 = 5'd18; 5'd29: scale_2_3 = 5'd19; default: scale_2_3 = 5'd0;
        endcase
    end
endfunction

// Use pixel_x_core for coin detection
wire is_on_coin0 = (pixel_x_core >= coin0_x_start) && (pixel_x_core < coin0_x_start + COIN_W) && (pixel_y_core >= coin0_y_start) && (pixel_y_core < coin0_y_start + COIN_H);
wire is_on_coin1 = (pixel_x_core >= coin1_x_start) && (pixel_x_core < coin1_x_start + COIN_W) && (pixel_y_core >= coin1_y_start) && (pixel_y_core < coin1_y_start + COIN_H);
wire is_on_coin2 = (pixel_x_core >= coin2_x_start) && (pixel_x_core < coin2_x_start + COIN_W) && (pixel_y_core >= coin2_y_start) && (pixel_y_core < coin2_y_start + COIN_H);

// $100 bill is 20x10 source, scaled 2x to 40x20
localparam BILL_W = 40;
localparam BILL_H = 20;
wire is_on_coin3 = (pixel_x_core >= coin3_x_start) && (pixel_x_core < coin3_x_start + BILL_W) && (pixel_y_core >= coin3_y_start) && (pixel_y_core < coin3_y_start + BILL_H);

wire is_on_any_coin = is_on_coin0 || is_on_coin1 || is_on_coin2 || is_on_coin3;

always @ (posedge clk) begin
    if (rst) coin_addr <= 0;
    else if (is_on_coin0)
        coin_addr <= scale_2_3(pixel_y_core - coin0_y_start) * 20 + scale_2_3(pixel_x_core - coin0_x_start);
    else if (is_on_coin1)
        coin_addr <= scale_2_3(pixel_y_core - coin1_y_start) * 20 + scale_2_3(pixel_x_core - coin1_x_start);
    else if (is_on_coin2)
        coin_addr <= scale_2_3(pixel_y_core - coin2_y_start) * 20 + scale_2_3(pixel_x_core - coin2_x_start);
    else if (is_on_coin3)
        coin_addr <= ((pixel_y_core - coin3_y_start) >> 1) * 20 + ((pixel_x_core - coin3_x_start) >> 1);
    else coin_addr <= 0;
end
reg [11:0] coin_pixel_data;
always @(*)
begin
    if (is_on_coin0) coin_pixel_data = coin1_data_out;
    else if (is_on_coin1) coin_pixel_data = coin5_data_out;
    else if (is_on_coin2) coin_pixel_data = coin10_data_out;
    else if (is_on_coin3) coin_pixel_data = coin100_data_out;
    else coin_pixel_data = 12'h000;
end
always @(*)
begin
    case (coin_index)
        2'd0: begin coin_selectbox_x = coin0_x_start - 3; coin_selectbox_y = coin0_y_start - 3; end
        2'd1: begin coin_selectbox_x = coin1_x_start - 3; coin_selectbox_y = coin1_y_start - 3; end
        2'd2: begin coin_selectbox_x = coin2_x_start - 3; coin_selectbox_y = coin2_y_start - 3; end
        2'd3: begin coin_selectbox_x = coin3_x_start - 3; coin_selectbox_y = coin3_y_start - 3; end
        default: begin coin_selectbox_x = coin0_x_start - 3; coin_selectbox_y = coin0_y_start - 3; end
    endcase
end
wire [9:0] coin_selectbox_w = (coin_index == 2'd3) ? (BILL_W + 6) : (COIN_W + 6);
// Height depends on item type
wire [9:0] coin_selectbox_h = (coin_index == 2'd3) ? (BILL_H + 6) : (COIN_H + 6);

localparam COIN_BORDER_WIDTH = 2;
// Use pixel_x_core
wire on_coin_selectbox_outer = (pixel_x_core >= coin_selectbox_x) && (pixel_x_core < coin_selectbox_x + coin_selectbox_w) && (pixel_y_core >= coin_selectbox_y) && (pixel_y_core < coin_selectbox_y + coin_selectbox_h);
wire on_coin_selectbox_inner = (pixel_x_core >= coin_selectbox_x + COIN_BORDER_WIDTH) && (pixel_x_core < coin_selectbox_x + coin_selectbox_w - COIN_BORDER_WIDTH) && (pixel_y_core >= coin_selectbox_y + COIN_BORDER_WIDTH) && (pixel_y_core < coin_selectbox_y + coin_selectbox_h - COIN_BORDER_WIDTH);
wire is_on_coin_selectbox_border = on_coin_selectbox_outer && ~on_coin_selectbox_inner;
// ------------------------------------------------------------------------
// Pixel Generation (Layering) Logic
// ------------------------------------------------------------------------
// Use pixel_x_core for DOT LOGIC
`define DOT_LOGIC(ITEM_INDEX, SPRITE_X, SPRITE_Y) \
    wire is_in_dot_v_range_``ITEM_INDEX = (pixel_y_core >= SPRITE_Y + 1) && (pixel_y_core < SPRITE_Y + 9); \
    wire [2:0] dy_``ITEM_INDEX = pixel_y_core - (SPRITE_Y + 1); \
    wire [2:0] dx1_``ITEM_INDEX = pixel_x_core - (SPRITE_X + 3); \
    wire [2:0] dx2_``ITEM_INDEX = pixel_x_core - (SPRITE_X + 12); \
    wire [2:0] dx3_``ITEM_INDEX = pixel_x_core - (SPRITE_X + 21); \
    wire [2:0] dx4_``ITEM_INDEX = pixel_x_core - (SPRITE_X + 30); \
    wire [2:0] dx5_``ITEM_INDEX = pixel_x_core - (SPRITE_X + 39); \
    wire is_corner_y07_``ITEM_INDEX = (dy_``ITEM_INDEX == 0 || dy_``ITEM_INDEX == 7); \
    wire is_corner_y16_``ITEM_INDEX = (dy_``ITEM_INDEX == 1 || dy_``ITEM_INDEX == 6); \
    wire mask1_``ITEM_INDEX = (is_corner_y07_``ITEM_INDEX && (dx1_``ITEM_INDEX <= 1 || dx1_``ITEM_INDEX >= 6)) || (is_corner_y16_``ITEM_INDEX && (dx1_``ITEM_INDEX == 0 || dx1_``ITEM_INDEX == 7)); \
    wire is_dot1_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x_core >= SPRITE_X + 3)  && (pixel_x_core < SPRITE_X + 11) && !mask1_``ITEM_INDEX; \
    wire mask2_``ITEM_INDEX = (is_corner_y07_``ITEM_INDEX && (dx2_``ITEM_INDEX <= 1 || dx2_``ITEM_INDEX >= 6)) || (is_corner_y16_``ITEM_INDEX && (dx2_``ITEM_INDEX == 0 || dx2_``ITEM_INDEX == 7)); \
    wire is_dot2_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x_core >= SPRITE_X + 12) && (pixel_x_core < SPRITE_X + 20) && !mask2_``ITEM_INDEX; \
    wire mask3_``ITEM_INDEX = (is_corner_y07_``ITEM_INDEX && (dx3_``ITEM_INDEX <= 1 || dx3_``ITEM_INDEX >= 6)) || (is_corner_y16_``ITEM_INDEX && (dx3_``ITEM_INDEX == 0 || dx3_``ITEM_INDEX == 7)); \
    wire is_dot3_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x_core >= SPRITE_X + 21) && (pixel_x_core < SPRITE_X + 29) && !mask3_``ITEM_INDEX; \
    wire mask4_``ITEM_INDEX = (is_corner_y07_``ITEM_INDEX && (dx4_``ITEM_INDEX <= 1 || dx4_``ITEM_INDEX >= 6)) || (is_corner_y16_``ITEM_INDEX && (dx4_``ITEM_INDEX == 0 || dx4_``ITEM_INDEX == 7)); \
    wire is_dot4_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x_core >= SPRITE_X + 30) && (pixel_x_core < SPRITE_X + 38) && !mask4_``ITEM_INDEX; \
    wire mask5_``ITEM_INDEX = (is_corner_y07_``ITEM_INDEX && (dx5_``ITEM_INDEX <= 1 || dx5_``ITEM_INDEX >= 6)) || (is_corner_y16_``ITEM_INDEX && (dx5_``ITEM_INDEX == 0 || dx5_``ITEM_INDEX == 7)); \
    wire is_dot5_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x_core >= SPRITE_X + 39) && (pixel_x_core < SPRITE_X + 47) && !mask5_``ITEM_INDEX; \
    wire is_dot_pixel_``ITEM_INDEX = is_dot1_pixel_``ITEM_INDEX || is_dot2_pixel_``ITEM_INDEX || is_dot3_pixel_``ITEM_INDEX || is_dot4_pixel_``ITEM_INDEX || is_dot5_pixel_``ITEM_INDEX; \
    wire [11:0] dot_color_``ITEM_INDEX; \
    wire [2:0] eff_cart_``ITEM_INDEX = dispense_completed ? 3'd0 : cart_quantity[ITEM_INDEX]; \
    assign dot_color_``ITEM_INDEX = \
        (is_dot1_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] < 1) ? COLOR_GRAY : ((stock[ITEM_INDEX] - eff_cart_``ITEM_INDEX < 1) ? COLOR_GREEN : COLOR_BLUE)) : \
        (is_dot2_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] < 2) ? COLOR_GRAY : ((stock[ITEM_INDEX] - eff_cart_``ITEM_INDEX < 2) ? COLOR_GREEN : COLOR_BLUE)) : \
        (is_dot3_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] < 3) ? COLOR_GRAY : ((stock[ITEM_INDEX] - eff_cart_``ITEM_INDEX < 3) ? COLOR_GREEN : COLOR_BLUE)) : \
        (is_dot4_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] < 4) ? COLOR_GRAY : ((stock[ITEM_INDEX] - eff_cart_``ITEM_INDEX < 4) ? COLOR_GREEN : COLOR_BLUE)) : \
        (is_dot5_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] < 5) ? COLOR_GRAY : ((stock[ITEM_INDEX] - eff_cart_``ITEM_INDEX < 5) ? COLOR_GREEN : COLOR_BLUE)) : \
        12'h000;
localparam BASE_X_0=10, BASE_Y_0=14; localparam BASE_X_1=20, BASE_Y_1=14; localparam BASE_X_2=30, BASE_Y_2=14;
localparam BASE_X_3=10, BASE_Y_3=26; localparam BASE_X_4=20, BASE_Y_4=26; localparam BASE_X_5=30, BASE_Y_5=26;
localparam BASE_X_6=10, BASE_Y_6=37; localparam BASE_X_7=20, BASE_Y_7=37; localparam BASE_X_8=30, BASE_Y_8=37;
localparam COLOR_GRAY = 12'h888; localparam COLOR_BLUE = 12'h00F; localparam COLOR_GREEN = 12'h0A0;
wire [9:0] sprite_x_start_0 = H_START + BASE_X_0 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_0 = V_START + BASE_Y_0 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_1 = H_START + BASE_X_1 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_1 = V_START + BASE_Y_1 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_2 = H_START + BASE_X_2 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_2 = V_START + BASE_Y_2 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_3 = H_START + BASE_X_3 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_3 = V_START + BASE_Y_3 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_4 = H_START + BASE_X_4 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_4 = V_START + BASE_Y_4 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_5 = H_START + BASE_X_5 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_5 = V_START + BASE_Y_5 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_6 = H_START + BASE_X_6 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_6 = V_START + BASE_Y_6 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_7 = H_START + BASE_X_7 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_7 = V_START + BASE_Y_7 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_8 = H_START + BASE_X_8 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2); wire [9:0] sprite_y_start_8 = V_START + BASE_Y_8 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
`DOT_LOGIC(0, sprite_x_start_0, sprite_y_start_0) `DOT_LOGIC(1, sprite_x_start_1, sprite_y_start_1) `DOT_LOGIC(2, sprite_x_start_2, sprite_y_start_2)
`DOT_LOGIC(3, sprite_x_start_3, sprite_y_start_3) `DOT_LOGIC(4, sprite_x_start_4, sprite_y_start_4) `DOT_LOGIC(5, sprite_x_start_5, sprite_y_start_5)
`DOT_LOGIC(6, sprite_x_start_6, sprite_y_start_6) `DOT_LOGIC(7, sprite_x_start_7, sprite_y_start_7) `DOT_LOGIC(8, sprite_x_start_8, sprite_y_start_8)

// REGISTER OUTPUT on CLK domain
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*)
begin
    if (~video_on) rgb_next = 12'h000;
    // --- Highest Priority: UI Text Overlays ---
    else if (is_help_active) rgb_next = help_rgb;
    else if (is_text_area && text_pixel) rgb_next = 12'hFFF;
    else if (is_price_text_area && price_text_pixel) rgb_next = 12'h000;
    else if (is_paid_text_area && paid_text_pixel) rgb_next = 12'hFFF;
    else if (is_change_text_area && change_text_pixel) rgb_next = 12'h0F0;
    else if (is_refund_text_area && refund_text_pixel) rgb_next = 12'hFF0; // Yellow Refund/Failed Text
    else if (!sw[0] && is_avail_change_active) rgb_next = avail_change_rgb;
    else if (dispense_completed && is_disp_change_active) rgb_next = disp_change_rgb;
    // --- PAYMENT STATE UI ---
    else if (current_state == 1'b1 && !dispensing && !dispense_completed && is_coin_text_area && coin_text_pixel) rgb_next = 12'hFFF;
    else if (current_state == 1'b1 && !dispensing && !dispense_completed && is_on_coin_selectbox_border) rgb_next = 12'hFF0;
    else if (current_state == 1'b1 && !dispensing && !dispense_completed && is_on_any_coin && (coin_pixel_data != TRANSPARENT_COLOR)) rgb_next = coin_pixel_data;
    // --- SELECTION STATE UI ---
    // Note: selectbox_data_out comes from SRAM clocked by clk, so it is valid.
    else if (current_state == 1'b0 && is_on_sprite && (selectbox_data_out != TRANSPARENT_COLOR)) rgb_next = selectbox_data_out;
    // --- Stock Indicators (Dots) - Prioritized over Chassis ---
    else if (is_dot_pixel_0) rgb_next = dot_color_0;
    else if (is_dot_pixel_1) rgb_next = dot_color_1;
    else if (is_dot_pixel_2) rgb_next = dot_color_2;
    else if (is_dot_pixel_3) rgb_next = dot_color_3;
    else if (is_dot_pixel_4) rgb_next = dot_color_4;
    else if (is_dot_pixel_5) rgb_next = dot_color_5;
    else if (is_dot_pixel_6) rgb_next = dot_color_6;
    else if (is_dot_pixel_7) rgb_next = dot_color_7;
    else if (is_dot_pixel_8) rgb_next = dot_color_8;
    // --- Vending Machine Chassis (with transparency) ---
    else if ( on_background_reg3 && (data_out != TRANSPARENT_COLOR) ) rgb_next = data_out;
    // --- Behind the Chassis Window ---
    else if (animation_active && is_on_animation && (anim_pixel_data != TRANSPARENT_COLOR)) rgb_next = anim_pixel_data;
    else if (is_on_green_bg_reg_s3 && (green_bg_data_out != TRANSPARENT_COLOR)) rgb_next = green_bg_data_out;
    // --- Fallback/Border Color ---
    else rgb_next = 12'h000;
end
assign VGA_RED   = rgb_reg[11:8];
assign VGA_GREEN = rgb_reg[7:4];
assign VGA_BLUE  = rgb_reg[3:0];
endmodule