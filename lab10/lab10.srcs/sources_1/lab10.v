`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: lab10
// Project Name: Vending Machine
// Description: A Vending Machine controller with VGA display
//              State 0 (IDLE): Display welcome screen background
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

// declare SRAM control signals
wire [11:0] sram_addr;
wire [11:0] data_in;
wire [11:0] data_out;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [11:0] pixel_addr;

// Declare the video buffer size (background image for State 0: IDLE)
localparam VBUF_W = 40; // video buffer width
localparam VBUF_H = 70; // video buffer height

// Instiantiate the VGA sync signal generator
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
// The following code describes an initialized SRAM memory block that
// stores the 40x70 background image (2800 words).
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(12), .RAM_SIZE(VBUF_W*VBUF_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Scale the 40x70 background image to fill the 640x480 display.
// Scaling factors: horizontal 16x (640/40), vertical ~7x (480/70)
// (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
always @ (posedge clk) begin
  if (~reset_n)
    pixel_addr <= 0;
  else
    // Scale up the 40x70 image for the 640x480 display
    // pixel_x >> 4 divides by 16, pixel_y / 7 (approximated with >> 3 for simplicity)
    pixel_addr <= (pixel_y / 7) * VBUF_W + (pixel_x >> 4);
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else
    rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
