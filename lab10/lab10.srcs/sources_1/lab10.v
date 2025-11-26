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

// Instantiate debounce modules for each button
debounce deb0 (.clk(clk), .reset(~reset_n), .btn_in(usr_btn[0]), .btn_out(btn_debounced[0]));
debounce deb1 (.clk(clk), .reset(~reset_n), .btn_in(usr_btn[1]), .btn_out(btn_debounced[1]));
debounce deb2 (.clk(clk), .reset(~reset_n), .btn_in(usr_btn[2]), .btn_out(btn_debounced[2]));
debounce deb3 (.clk(clk), .reset(~reset_n), .btn_in(usr_btn[3]), .btn_out(btn_debounced[3]));

// General control signals
wire [11:0] data_in;
wire        sram_we, sram_en;

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
    .reset(~reset_n),
    .btn_left(btn_debounced[1]), // Swapped to match user feedback
    .btn_right(btn_debounced[0]), // Swapped to match user feedback
    .selection_index(selection_index)
);

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
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
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
assign sram_we = usr_btn[3]; // Vivado BRAM inference bug requires 'we' to be non-constant
assign sram_en = 1;
assign data_in = 12'h000;

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
  if (~reset_n)
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
    if (~reset_n)
        selectbox_addr <= 0;
    else if (is_on_sprite)
        selectbox_addr <= ((pixel_y - sprite_y_start) / SPRITE_SCALE_FACTOR) * BOX_W + ((pixel_x - sprite_x_start) / SPRITE_SCALE_FACTOR);
    else
        selectbox_addr <= 0;
end

// ------------------------------------------------------------------------
// Pixel Generation (Layering) Logic
// ------------------------------------------------------------------------
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
    // Priority 1: Blanking periods (sync)
    if (~video_on) begin
        rgb_next = 12'h000;
    // Priority 2: Selection Box (if pixel is not transparent)
    end else if ( is_on_sprite && (selectbox_data_out != TRANSPARENT_COLOR) ) begin
        rgb_next = selectbox_data_out;
    // Priority 3: Scaled Background Image
    end else if ( (pixel_x >= H_START && pixel_x <= H_END) && 
                  (pixel_y >= V_START && pixel_y <= V_END) ) begin
        rgb_next = data_out;
    // Priority 4: Screen Borders
    end else begin
        rgb_next = 12'h000;
    end
end

assign VGA_RED   = rgb_reg[11:8];
assign VGA_GREEN = rgb_reg[7:4];
assign VGA_BLUE  = rgb_reg[3:0];

endmodule