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

// Sprite SRAM signals
wire [11:0] selectbox_data_out;
reg  [6:0]  selectbox_addr; // Address for the sprite SRAM

// FSM and Selection Logic
wire [3:0] selection_index;

vending_fsm fsm0 (
    .clk(clk),
    .reset(rst),
    .btn_left(btn_debounced[1]),
    .btn_right(btn_debounced[0]),
    .selection_index(selection_index)
);

// ------------------------------------------------------------------------
// Stock & Cart Management
// ------------------------------------------------------------------------
reg [2:0] stock [0:8];         // Available stock for each item
reg [2:0] cart_quantity [0:8]; // Items selected by user (the "shopping cart")

integer i;
initial begin
    // Initialize stock as per user request
    stock[0] = 5; stock[1] = 0; stock[2] = 0;
    stock[3] = 5; stock[4] = 5; stock[5] = 0;
    stock[6] = 0; stock[7] = 0; stock[8] = 5;

    // Initialize cart to all zeros
    for (i = 0; i < 9; i = i + 1) begin
        cart_quantity[i] = 0;
    end
end

// Cart update logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset cart on system reset
        cart_quantity[0] <= 0; cart_quantity[1] <= 0; cart_quantity[2] <= 0;
        cart_quantity[3] <= 0; cart_quantity[4] <= 0; cart_quantity[5] <= 0;
        cart_quantity[6] <= 0; cart_quantity[7] <= 0; cart_quantity[8] <= 0;
    end else if (btn2_posedge) begin
        // On btn2 press, cycle the cart quantity for the selected item
        if (cart_quantity[selection_index] >= stock[selection_index]) begin
            cart_quantity[selection_index] <= 0;
        end else begin
            cart_quantity[selection_index] <= cart_quantity[selection_index] + 1;
        end
    end
end
// TODO: Add logic for btn3 to submit the order (all non-zero cart_quantity items)


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


// Tie off unused/static signals
assign usr_led[0] = btn_debounced[0];
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
always @(*) begin
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

// AGU for the background image
always @ (posedge clk) begin
  if (rst)
    pixel_addr <= 0;
  else if (pixel_x >= H_START && pixel_x <= H_END && pixel_y >= V_START && pixel_y <= V_END)
    pixel_addr <= ((pixel_y - V_START) / SCALE_FACTOR) * VBUF_W + ((pixel_x - H_START) / SCALE_FACTOR);
  else
    pixel_addr <= 0;
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

// ------------------------------------------------------------------------
// Pixel Generation (Layering) Logic
// ------------------------------------------------------------------------

wire on_background = (pixel_x >= H_START && pixel_x <= H_END) && 
                     (pixel_y >= V_START && pixel_y <= V_END);

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
        (is_dot1_pixel_``ITEM_INDEX) ? ((0 + stock[ITEM_INDEX] >= 5) ? ((0 + cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot2_pixel_``ITEM_INDEX) ? ((1 + stock[ITEM_INDEX] >= 5) ? ((1 + cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot3_pixel_``ITEM_INDEX) ? ((2 + stock[ITEM_INDEX] >= 5) ? ((2 + cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot4_pixel_``ITEM_INDEX) ? ((3 + stock[ITEM_INDEX] >= 5) ? ((3 + cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
        (is_dot5_pixel_``ITEM_INDEX) ? ((4 + stock[ITEM_INDEX] >= 5) ? ((4 + cart_quantity[ITEM_INDEX] >= 5) ? COLOR_GREEN : COLOR_BLUE) : COLOR_GRAY) : \
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

always @(*) begin
    // Priority 1: Blanking periods (sync)
    if (~video_on) begin
        rgb_next = 12'h000;
    // Priority 2: Selection Box (moves on top of dots)
    end else if ( is_on_sprite && (selectbox_data_out != TRANSPARENT_COLOR) ) begin
        rgb_next = selectbox_data_out;
    // Priority 3: Dots for all 9 items
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
    // Priority 4: Scaled Background Image
    end else if ( on_background ) begin
        rgb_next = data_out;
    // Priority 5: Screen Borders
    end else begin
        rgb_next = 12'h000;
    end
end

assign VGA_RED   = rgb_reg[11:8];
assign VGA_GREEN = rgb_reg[7:4];
assign VGA_BLUE  = rgb_reg[3:0];

endmodule