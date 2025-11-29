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
    .reset(rst),
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
    .btn_up(btn_debounced[0]),      // btn0 - move up
    .btn_down(btn_debounced[1]),    // btn1 - move down
    .coin_index(coin_index)
);
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
wire dispenser_done;                      // Dispenser calculation complete
wire dispenser_success;                   // Exact change possible
change_dispenser change_disp0 (
    .clk(clk),
    .reset(rst),
    .start(dispenser_start),
    .change_amount(change_amount),
    .avail_coin1(avail_coins[0]),
    .avail_coin5(avail_coins[1]),
    .avail_coin10(avail_coins[2]),
    .dispense_coin1(dispense_coin1_wire),
    .dispense_coin5(dispense_coin5_wire),
    .dispense_coin10(dispense_coin10_wire),
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
        dispensed_coins[0] <= 8'd0;
        dispensed_coins[1] <= 8'd0;
        dispensed_coins[2] <= 8'd0;
        coins_inserted[0] <= 8'd0;
        coins_inserted[1] <= 8'd0;
        coins_inserted[2] <= 8'd0;
        // Reset coin inventory to initial values
        avail_coins[0] <= 8'd10;  // 10 x $1 coins
        avail_coins[1] <= 8'd10;  // 10 x $5 coins
        avail_coins[2] <= 8'd10;  // 10 x $10 coins
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
            dispensed_coins[0] <= 8'd0;
            dispensed_coins[1] <= 8'd0;
            dispensed_coins[2] <= 8'd0;
            coins_inserted[0] <= 8'd0;
            coins_inserted[1] <= 8'd0;
            coins_inserted[2] <= 8'd0;
        // Priority 1: When dispensing is done, update inventories and reset coins
        end else if (dispensing && dispenser_done) begin
            if (dispenser_success) begin
                // Update available coins: subtract dispensed, add inserted
                avail_coins[0] <= avail_coins[0] - dispense_coin1_wire + coins_inserted[0];
                avail_coins[1] <= avail_coins[1] - dispense_coin5_wire + coins_inserted[1];
                avail_coins[2] <= avail_coins[2] - dispense_coin10_wire + coins_inserted[2];
                // Update stock: decrease by cart quantities
                stock[0] <= stock[0] - cart_quantity[0];
                stock[1] <= stock[1] - cart_quantity[1];
                stock[2] <= stock[2] - cart_quantity[2];
                stock[3] <= stock[3] - cart_quantity[3];
                stock[4] <= stock[4] - cart_quantity[4];
                stock[5] <= stock[5] - cart_quantity[5];
                stock[6] <= stock[6] - cart_quantity[6];
                stock[7] <= stock[7] - cart_quantity[7];
                stock[8] <= stock[8] - cart_quantity[8];
                // Store dispensed amounts for display
                dispensed_coins[0] <= dispense_coin1_wire;
                dispensed_coins[1] <= dispense_coin5_wire;
                dispensed_coins[2] <= dispense_coin10_wire;
                // Reset inserted coins
                coins_inserted[0] <= 8'd0;
                coins_inserted[1] <= 8'd0;
                coins_inserted[2] <= 8'd0;
                // Mark dispensing as completed
                dispense_completed <= 1'b1;
            end
            dispensing <= 1'b0;
        // Priority 2: Start dispensing when btn3 pressed in PAYMENT with sufficient payment
        end else if (current_state == 1'b1 && btn3_posedge && payment_sufficient && !dispensing && !dispense_completed) begin
            dispenser_start <= 1'b1;
            dispensing <= 1'b1;
        // Priority 3: Coin insertion in PAYMENT state
        end else if (current_state == 1'b1 && btn2_posedge && !dispensing) begin
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
reg [7:0] coins_inserted [0:2]; // Number of each coin type inserted
                                 // [0] = $1 coins, [1] = $5 coins, [2] = $10 coins
reg [7:0] avail_coins [0:2];     // Machine's available coins for change
                                 // [0] = $1 coins, [1] = $5 coins, [2] = $10 coins
reg [7:0] dispensed_coins [0:2]; // Coins to be dispensed as change
                                 // [0] = $1 coins, [1] = $5 coins, [2] = $10 coins
integer i;
initial begin
    // Initialize stock as per user request
    stock[0] = 5; stock[1] = 0; stock[2] = 0;
    stock[3] = 5; stock[4] = 5; stock[5] = 0;
    stock[6] = 0; stock[7] = 0; stock[8] = 5;
    // Initialize prices (as per SPECIFICATION.md example)
    drink_price[0] = 10; drink_price[1] = 5;  drink_price[2] = 15;
    drink_price[3] = 8;  drink_price[4] = 12; drink_price[5] = 6;
    drink_price[6] = 20; drink_price[7] = 10; drink_price[8] = 15;
    // Initialize cart to all zeros
    for (i = 0; i < 9; i = i + 1) begin
        cart_quantity[i] = 0;
    end
    // Initialize coins inserted to zero
    coins_inserted[0] = 0;
    coins_inserted[1] = 0;
    coins_inserted[2] = 0;
    // Initialize machine's coin inventory (AVAIL)
    avail_coins[0] = 10;  // 10 x $1 coins
    avail_coins[1] = 10;  // 10 x $5 coins
    avail_coins[2] = 10;  // 10 x $10 coins
    // Initialize dispensed coins to zero
    dispensed_coins[0] = 0;
    dispensed_coins[1] = 0;
    dispensed_coins[2] = 0;
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
// Coin display parameters (20x20 pixels, displayed in right area)
localparam COIN_W = 20;
localparam COIN_H = 20;
localparam COIN_X_START = 480;   // Right side of screen
localparam COIN_Y_SPACING = 110; // Vertical spacing between coins (increased for text)
localparam COIN_Y_BASE = 80;     // Start Y position for first coin
// Coin positions (3 coins vertically arranged with text below)
// Coin 0 ($1):  X=480, Y=80,  Text: Y=104
// Coin 1 ($5):  X=480, Y=190, Text: Y=214
// Coin 2 ($10): X=480, Y=300, Text: Y=324
wire [9:0] coin0_x_start = COIN_X_START;
wire [9:0] coin0_y_start = COIN_Y_BASE;
wire [9:0] coin1_x_start = COIN_X_START;
wire [9:0] coin1_y_start = COIN_Y_BASE + COIN_Y_SPACING;
wire [9:0] coin2_x_start = COIN_X_START;
wire [9:0] coin2_y_start = COIN_Y_BASE + COIN_Y_SPACING * 2;
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
// ------------------------------------------------------------------------
// Text Renderer (displays "TOTAL: $XXX" in top-left corner)
// ------------------------------------------------------------------------
wire text_pixel;
wire is_text_area;
text_renderer text_render0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x),
  .pixel_y(pixel_y),
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
  .pixel_x(pixel_x),
  .pixel_y(pixel_y),
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
  .pixel_x(pixel_x),
  .pixel_y(pixel_y),
  .change_amount(change_amount),
  .text_pixel(change_text_pixel),
  .is_text_area(is_change_text_area)
);
// ------------------------------------------------------------------------
// Coin Count Display (displays count below each coin)
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
  .coin1_count(coins_inserted[0]),
  .coin5_count(coins_inserted[1]),
  .coin10_count(coins_inserted[2]),
  .avail1_count(avail_coins[0]),
  .avail5_count(avail_coins[1]),
  .avail10_count(avail_coins[2]),
  .text_pixel(coin_text_pixel),
  .is_coin_text_area(is_coin_text_area)
);
// ------------------------------------------------------------------------
// Dispensed Count Display (shows DISP:XX below AVAIL line)
// ------------------------------------------------------------------------
wire disp_text_pixel;
wire is_disp_text_area;
dispensed_count_display disp_count_disp0 (
  .clk(clk),
  .reset(rst),
  .pixel_x(pixel_x),
  .pixel_y(pixel_y),
  .coin0_y_start(coin0_y_start),
  .coin1_y_start(coin1_y_start),
  .coin2_y_start(coin2_y_start),
  .disp1_count(dispensed_coins[0]),
  .disp5_count(dispensed_coins[1]),
  .disp10_count(dispensed_coins[2]),
  .text_pixel(disp_text_pixel),
  .is_disp_text_area(is_disp_text_area)
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
// Coin SRAM modules (20x20 pixels each)
// ------------------------------------------------------------------------
wire [11:0] coin1_data_out, coin5_data_out, coin10_data_out;
reg [8:0] coin_addr;  // 9 bits for 400 pixels (20*20)
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
// Tie off unused/static signals
// LED[3:0] displays lower 4 bits of total_due for debugging
// This allows you to see if price calculation is working
// Example: cart with 1x $10 drink → total_due = 10 → LED = 4'b1010
assign usr_led[3:0] = total_due[3:0];
assign sram_we = sram_we_reg; // Connected to an always-zero register to avoid write bug
assign sram_en = 1;
assign data_in = 12'h000;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sram_we_reg <= 1'b0;
    end else begin
        sram_we_reg <= 1'b0; // Always keep write enable low for background SRAM
    end
end
// ------------------------------------------------------------------------
// Sprite and AGU (Address Generation Unit) Logic
// ------------------------------------------------------------------------
localparam SPRITE_SCALE_FACTOR = 2;
// Logic to calculate the sprite coordinates based on a center point
always @(*)
begin
    // Define the CENTER point of the selection box on the 40x70 background grid
    case (selection_index)
        // Row 1
        0: begin base_x = 10; base_y = 14; end // Y-start adjusted
        1: begin base_x = 20; base_y = 14; end
        2: begin base_x = 30; base_y = 14; end
        // Row 2
        3: begin base_x = 10; base_y = 26; end // Y-spacing adjusted to 12
        4: begin base_x = 20; base_y = 26; end
        5: begin base_x = 30; base_y = 26; end
        // Row 3
        6: begin base_x = 10; base_y = 37; end // Y-spacing adjusted to 11
        7: begin base_x = 20; base_y = 37; end
        8: begin base_x = 30; base_y = 37; end
        default: begin base_x = 10; base_y = 14; end
    endcase
    // Calculate the on-screen center point by scaling the base coordinates
    on_screen_center_x = H_START + base_x * SCALE_FACTOR;
    on_screen_center_y = V_START + base_y * SCALE_FACTOR;
    // Calculate the top-left corner for the SCALED sprite
    sprite_x_start = on_screen_center_x - (BOX_W * SPRITE_SCALE_FACTOR / 2);
    sprite_y_start = on_screen_center_y - (BOX_H * SPRITE_SCALE_FACTOR / 2);
end
// AGU for the background image (3-stage pipeline to fix timing)
// Stage 1: Perform the first multiplication for scaling factor
always @(posedge clk) begin
    on_background_reg1 <= (pixel_x >= H_START && pixel_x <= H_END) && (pixel_y >= V_START && pixel_y <= V_END);
    if ((pixel_x >= H_START && pixel_x <= H_END) && (pixel_y >= V_START && pixel_y <= V_END)) begin
        scaled_x_stage1 <= (pixel_x - H_START) * 171;
        scaled_y_stage1 <= (pixel_y - V_START) * 171;
    end
end

// Stage 2: Perform the scaling shift and the second multiplication (by VBUF_W)
always @(posedge clk) begin
    on_background_reg2 <= on_background_reg1;
    on_background_reg3 <= on_background_reg2; // Pass through for 3rd stage
    if (on_background_reg1) begin
        scaled_x_stage2 <= scaled_x_stage1 >> 10;
        scaled_y_stage2 <= scaled_y_stage1 >> 10;
        y_mult_40_stage2 <= (scaled_y_stage1 >> 10) * VBUF_W;
    end
end

// Stage 3: Final addition, registered output.
always @(posedge clk) begin
    if (rst)
        pixel_addr <= 0;
    else if (on_background_reg2)
        pixel_addr <= y_mult_40_stage2 + scaled_x_stage2;
    else
        pixel_addr <= 0; // Default address when not on background
end
// AGU for the SelectBox sprite (scaled 2x)
wire [9:0] scaled_sprite_w = BOX_W * SPRITE_SCALE_FACTOR;
wire [9:0] scaled_sprite_h = BOX_H * SPRITE_SCALE_FACTOR;
wire is_on_sprite = (pixel_x >= sprite_x_start) && (pixel_x < sprite_x_start + scaled_sprite_w) &&
                    (pixel_y >= sprite_y_start) && (pixel_y < sprite_y_start + scaled_sprite_h);
always @ (posedge clk) begin
    if (rst)
        selectbox_addr <= 0;
    else if (is_on_sprite)
        selectbox_addr <= ((pixel_y - sprite_y_start) / SPRITE_SCALE_FACTOR) * BOX_W + ((pixel_x - sprite_x_start) / SPRITE_SCALE_FACTOR);
    else
        selectbox_addr <= 0;
end
// AGU for the Green Background sprite
localparam GREEN_BG_X_START = 9;
localparam GREEN_BG_Y_START = 56;
wire on_background = (pixel_x >= H_START && pixel_x <= H_END) &&
                     (pixel_y >= V_START && pixel_y <= V_END);
reg is_on_green_bg_reg;
reg is_on_green_bg_reg_s3;

// AGU for the Green Background sprite (pipelined)

always @(posedge clk) begin

    if (rst) begin

        green_bg_addr <= 0;

        is_on_green_bg_reg <= 1'b0;
        is_on_green_bg_reg_s3 <= 1'b0;

    end else begin
        is_on_green_bg_reg_s3 <= is_on_green_bg_reg;
        // Check if the pipelined coordinates fall within the green bg sprite area

        if (on_background_reg2 && // Use the appropriate delayed signal

            (scaled_x_stage2 >= GREEN_BG_X_START) && (scaled_x_stage2 < GREEN_BG_X_START + GREEN_BG_W) &&

            (scaled_y_stage2 >= GREEN_BG_Y_START) && (scaled_y_stage2 < GREEN_BG_Y_START + GREEN_BG_H))

        begin

            is_on_green_bg_reg <= 1'b1;

            green_bg_addr <= (scaled_y_stage2 - GREEN_BG_Y_START) * GREEN_BG_W + (scaled_x_stage2 - GREEN_BG_X_START);

        end else begin

            is_on_green_bg_reg <= 1'b0;

            green_bg_addr <= 0;

        end

    end

end
// ------------------------------------------------------------------------
// Coin AGU and Display Logic (for PAYMENT state)
// ------------------------------------------------------------------------
// Check if pixel is on any coin
wire is_on_coin0 = (pixel_x >= coin0_x_start) && (pixel_x < coin0_x_start + COIN_W) &&
                   (pixel_y >= coin0_y_start) && (pixel_y < coin0_y_start + COIN_H);
wire is_on_coin1 = (pixel_x >= coin1_x_start) && (pixel_x < coin1_x_start + COIN_W) &&
                   (pixel_y >= coin1_y_start) && (pixel_y < coin1_y_start + COIN_H);
wire is_on_coin2 = (pixel_x >= coin2_x_start) && (pixel_x < coin2_x_start + COIN_W) &&
                   (pixel_y >= coin2_y_start) && (pixel_y < coin2_y_start + COIN_H);
wire is_on_any_coin = is_on_coin0 || is_on_coin1 || is_on_coin2;
// Calculate coin address (same for all coins since they're all 20x20)
always @ (posedge clk) begin
    if (rst)
        coin_addr <= 0;
    else if (is_on_coin0)
        coin_addr <= (pixel_y - coin0_y_start) * COIN_W + (pixel_x - coin0_x_start);
    else if (is_on_coin1)
        coin_addr <= (pixel_y - coin1_y_start) * COIN_W + (pixel_x - coin1_x_start);
    else if (is_on_coin2)
        coin_addr <= (pixel_y - coin2_y_start) * COIN_W + (pixel_x - coin2_x_start);
    else
        coin_addr <= 0;
end
// Select which coin data to display
reg [11:0] coin_pixel_data;
always @(*)
begin
    if (is_on_coin0)
        coin_pixel_data = coin1_data_out;  // $1 coin
    else if (is_on_coin1)
        coin_pixel_data = coin5_data_out;  // $5 coin
    else if (is_on_coin2)
        coin_pixel_data = coin10_data_out; // $10 coin
    else
        coin_pixel_data = 12'h000;
end
// Calculate coin selection box position based on coin_index
always @(*)
begin
    case (coin_index)
        2'd0: begin
            coin_selectbox_x = coin0_x_start - 3;  // Center around coin
            coin_selectbox_y = coin0_y_start - 3;
        end
        2'd1: begin
            coin_selectbox_x = coin1_x_start - 3;
            coin_selectbox_y = coin1_y_start - 3;
        end
        2'd2: begin
            coin_selectbox_x = coin2_x_start - 3;
            coin_selectbox_y = coin2_y_start - 3;
        end
        default: begin
            coin_selectbox_x = coin0_x_start - 3;
            coin_selectbox_y = coin0_y_start - 3;
        end
    endcase
end
// Check if pixel is on coin selection box BORDER (hollow box)
wire [9:0] coin_selectbox_w = COIN_W + 6;  // Coin width + border
wire [9:0] coin_selectbox_h = COIN_H + 6;  // Coin height + border
localparam COIN_BORDER_WIDTH = 2;  // Border thickness in pixels
// Check if on outer box
wire on_coin_selectbox_outer = (pixel_x >= coin_selectbox_x) && (pixel_x < coin_selectbox_x + coin_selectbox_w) &&
                                (pixel_y >= coin_selectbox_y) && (pixel_y < coin_selectbox_y + coin_selectbox_h);
// Check if on inner box (hollow area)
wire on_coin_selectbox_inner = (pixel_x >= coin_selectbox_x + COIN_BORDER_WIDTH) &&
                                (pixel_x < coin_selectbox_x + coin_selectbox_w - COIN_BORDER_WIDTH) &&
                                (pixel_y >= coin_selectbox_y + COIN_BORDER_WIDTH) &&
                                (pixel_y < coin_selectbox_y + coin_selectbox_h - COIN_BORDER_WIDTH);
// Only show border (outer box but not inner box)
wire is_on_coin_selectbox_border = on_coin_selectbox_outer && ~on_coin_selectbox_inner;
// ------------------------------------------------------------------------
// Pixel Generation (Layering) Logic
// ------------------------------------------------------------------------
// --- Dot Drawing Logic for ALL 9 items ---
// Constant base coordinates for each item
localparam BASE_X_0=10, BASE_Y_0=14;
localparam BASE_X_1=20, BASE_Y_1=14;
localparam BASE_X_2=30, BASE_Y_2=14;
localparam BASE_X_3=10, BASE_Y_3=26;
localparam BASE_X_4=20, BASE_Y_4=26;
localparam BASE_X_5=30, BASE_Y_5=26;
localparam BASE_X_6=10, BASE_Y_6=37;
localparam BASE_X_7=20, BASE_Y_7=37;
localparam BASE_X_8=30, BASE_Y_8=37;
// Dot Color Definitions
localparam COLOR_GRAY = 12'h888;
localparam COLOR_BLUE = 12'h00F;
localparam COLOR_GREEN = 12'h0A0; // Non-transparent green
// On-screen sprite start coordinates for each item slot
wire [9:0] sprite_x_start_0 = H_START + BASE_X_0 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_0 = V_START + BASE_Y_0 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_1 = H_START + BASE_X_1 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_1 = V_START + BASE_Y_1 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_2 = H_START + BASE_X_2 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_2 = V_START + BASE_Y_2 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_3 = H_START + BASE_X_3 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_3 = V_START + BASE_Y_3 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_4 = H_START + BASE_X_4 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_4 = V_START + BASE_Y_4 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_5 = H_START + BASE_X_5 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_5 = V_START + BASE_Y_5 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_6 = H_START + BASE_X_6 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_6 = V_START + BASE_Y_6 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_7 = H_START + BASE_X_7 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_7 = V_START + BASE_Y_7 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_x_start_8 = H_START + BASE_X_8 * SCALE_FACTOR - (BOX_W * SPRITE_SCALE_FACTOR / 2);
wire [9:0] sprite_y_start_8 = V_START + BASE_Y_8 * SCALE_FACTOR - (BOX_H * SPRITE_SCALE_FACTOR / 2);
`define DOT_LOGIC(ITEM_INDEX, SPRITE_X, SPRITE_Y) \
    wire is_in_dot_v_range_``ITEM_INDEX = (pixel_y >= SPRITE_Y + 1) && (pixel_y < SPRITE_Y + 9); \
    wire is_dot1_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x >= SPRITE_X + 3)  && (pixel_x < SPRITE_X + 11); \
    wire is_dot2_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x >= SPRITE_X + 12) && (pixel_x < SPRITE_X + 20); \
    wire is_dot3_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x >= SPRITE_X + 21) && (pixel_x < SPRITE_X + 29); \
    wire is_dot4_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x >= SPRITE_X + 30) && (pixel_x < SPRITE_X + 38); \
    wire is_dot5_pixel_``ITEM_INDEX = is_in_dot_v_range_``ITEM_INDEX && (pixel_x >= SPRITE_X + 39) && (pixel_x < SPRITE_X + 47); \
    wire is_dot_pixel_``ITEM_INDEX = is_dot1_pixel_``ITEM_INDEX || is_dot2_pixel_``ITEM_INDEX || is_dot3_pixel_``ITEM_INDEX || is_dot4_pixel_``ITEM_INDEX || is_dot5_pixel_``ITEM_INDEX; \
    wire [11:0] dot_color_``ITEM_INDEX; \
    assign dot_color_``ITEM_INDEX = \
        (is_dot1_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] >= 1) ? ((cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot2_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] >= 2) ? ((cart_quantity[ITEM_INDEX] >= 4) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot3_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] >= 3) ? ((cart_quantity[ITEM_INDEX] >= 3) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot4_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] >= 4) ? ((cart_quantity[ITEM_INDEX] >= 2) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot5_pixel_``ITEM_INDEX) ? ((stock[ITEM_INDEX] >= 5) ? ((cart_quantity[ITEM_INDEX] >= 1) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        12'h000;
`DOT_LOGIC(0, sprite_x_start_0, sprite_y_start_0)
`DOT_LOGIC(1, sprite_x_start_1, sprite_y_start_1)
`DOT_LOGIC(2, sprite_x_start_2, sprite_y_start_2)
`DOT_LOGIC(3, sprite_x_start_3, sprite_y_start_3)
`DOT_LOGIC(4, sprite_x_start_4, sprite_y_start_4)
`DOT_LOGIC(5, sprite_x_start_5, sprite_y_start_5)
`DOT_LOGIC(6, sprite_x_start_6, sprite_y_start_6)
`DOT_LOGIC(7, sprite_x_start_7, sprite_y_start_7)
`DOT_LOGIC(8, sprite_x_start_8, sprite_y_start_8)
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end
always @(*)
begin
    // Priority 1: Blanking periods (sync)
    if (~video_on) begin
        rgb_next = 12'h000;
    // Priority 2a: TOTAL text overlay (highest visible priority)
    end else if (is_text_area && text_pixel) begin
        rgb_next = 12'hFFF;  // White text
    // Priority 2b: PAID text overlay
    end else if (is_paid_text_area && paid_text_pixel) begin
        rgb_next = 12'hFFF;  // White text
    // Priority 2c: CHANGE text overlay (only if payment sufficient)
    end else if (is_change_text_area && change_text_pixel) begin
        rgb_next = 12'h0F0;  // Green text (payment complete!)
    // === PAYMENT STATE LAYERS ===
    // Priority 3a: Coin count text (PAYMENT state only)
    end else if (current_state == 1'b1 && is_coin_text_area && coin_text_pixel) begin
        rgb_next = 12'hFFF;  // White text for coin counts
    // Priority 3a2: Dispensed count text (PAYMENT state only)
    end else if (current_state == 1'b1 && is_disp_text_area && disp_text_pixel) begin
        rgb_next = 12'hF80;  // Orange text for dispensed amounts
    // Priority 3b: Coin selection box border (PAYMENT state only, hollow)
    end else if (current_state == 1'b1 && is_on_coin_selectbox_border) begin
        rgb_next = 12'hFF0;  // Yellow border for coin selection
    // Priority 3c: Coins (PAYMENT state only)
    end else if (current_state == 1'b1 && is_on_any_coin && (coin_pixel_data != TRANSPARENT_COLOR)) begin
        rgb_next = coin_pixel_data;
    // === SELECTION STATE LAYERS ===
    // Priority 4: Selection Box for drinks (SELECTION state only, moves on top of dots)
    end else if (current_state == 1'b0 && is_on_sprite && (selectbox_data_out != TRANSPARENT_COLOR)) begin
        rgb_next = selectbox_data_out;
    // Priority 5: Dots for all 9 items
    end else if (is_dot_pixel_0) begin
        rgb_next = dot_color_0;
    end else if (is_dot_pixel_1) begin
        rgb_next = dot_color_1;
    end else if (is_dot_pixel_2) begin
        rgb_next = dot_color_2;
    end else if (is_dot_pixel_3) begin
        rgb_next = dot_color_3;
    end else if (is_dot_pixel_4) begin
        rgb_next = dot_color_4;
    end else if (is_dot_pixel_5) begin
        rgb_next = dot_color_5;
    end else if (is_dot_pixel_6) begin
        rgb_next = dot_color_6;
    end else if (is_dot_pixel_7) begin
        rgb_next = dot_color_7;
    end else if (is_dot_pixel_8) begin
        rgb_next = dot_color_8;
    // Priority 5: Scaled Background Image
    end else if (is_on_green_bg_reg_s3 && (green_bg_data_out != TRANSPARENT_COLOR)) begin
        rgb_next = green_bg_data_out;
    end else if ( on_background_reg3 ) begin
        rgb_next = data_out;
    // Priority 6: Screen Borders
    end else begin
        rgb_next = 12'h000;
    end
end
assign VGA_RED   = rgb_reg[11:8];
assign VGA_GREEN = rgb_reg[7:4];
assign VGA_BLUE  = rgb_reg[3:0];
endmodule