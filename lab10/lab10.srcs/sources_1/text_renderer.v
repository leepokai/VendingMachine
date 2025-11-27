// text_renderer.v
// Module: Text Renderer
// Description: Renders text "TOTAL: $XXX" in the top-left corner of the screen
// Character size: 8x16 pixels
// Display position: (8, 8) starting point

module text_renderer (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire [15:0] total_due,    // Value to display (0-9999)
    output reg text_pixel,          // Output: 1 if text pixel should be drawn
    output reg is_text_area         // Output: 1 if current position is in text area
);

// Text display parameters
localparam TEXT_X_START = 8;
localparam TEXT_Y_START = 8;
localparam CHAR_WIDTH = 8;
localparam CHAR_HEIGHT = 16;
localparam NUM_CHARS = 10;  // "TOTAL: $XX"

// Calculate character position
wire [3:0] char_index;  // Which character (0-9)
wire [3:0] char_row;    // Which row within character (0-15)
wire [2:0] char_col;    // Which column within character (0-7)

wire in_text_x = (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + NUM_CHARS * CHAR_WIDTH);
wire in_text_y = (pixel_y >= TEXT_Y_START) && (pixel_y < TEXT_Y_START + CHAR_HEIGHT);

// CHAR_WIDTH = 8 = 2^3, so division by 8 is right shift by 3
wire [9:0] pixel_offset_x = pixel_x - TEXT_X_START;
assign char_index = pixel_offset_x[6:3];  // Divide by 8 (shift right 3)
assign char_col = pixel_offset_x[2:0];    // Modulo 8 (lower 3 bits)
assign char_row = (pixel_y - TEXT_Y_START);

// ASCII code for current character
reg [6:0] ascii_code;

// Convert total_due to BCD using Double Dabble algorithm
wire [3:0] bcd_ones, bcd_tens, bcd_hundreds, bcd_thousands;

bin2bcd bcd_converter (
    .clk(clk),
    .reset(reset),
    .binary(total_due),
    .bcd_ones(bcd_ones),
    .bcd_tens(bcd_tens),
    .bcd_hundreds(bcd_hundreds),
    .bcd_thousands(bcd_thousands)
);

// Determine which ASCII character to display based on position
always @(*) begin
    case (char_index)
        4'd0: ascii_code = 7'h54;  // 'T'
        4'd1: ascii_code = 7'h4F;  // 'O'
        4'd2: ascii_code = 7'h54;  // 'T'
        4'd3: ascii_code = 7'h41;  // 'A'
        4'd4: ascii_code = 7'h4C;  // 'L'
        4'd5: ascii_code = 7'h3A;  // ':'
        4'd6: ascii_code = 7'h24;  // '$'
        4'd7: ascii_code = 7'h30 + bcd_hundreds;   // Hundreds digit (BCD)
        4'd8: ascii_code = 7'h30 + bcd_tens;       // Tens digit (BCD)
        4'd9: ascii_code = 7'h30 + bcd_ones;       // Ones digit (BCD)
        default: ascii_code = 7'h20;  // Space
    endcase
end

// Instantiate character ROM
wire char_pixel;

pc_vga_8x16_00_7F char_rom (
    .clk(clk),
    .ascii_code(ascii_code),
    .row(char_row),
    .col(char_col),
    .row_of_pixels(char_pixel)
);

// Output logic
always @(posedge clk) begin
    is_text_area <= in_text_x && in_text_y;

    if (in_text_x && in_text_y) begin
        text_pixel <= char_pixel;
    end else begin
        text_pixel <= 1'b0;
    end
end

endmodule
