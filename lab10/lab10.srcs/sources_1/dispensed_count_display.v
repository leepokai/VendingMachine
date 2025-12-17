// dispensed_count_display.v
// Module: Dispensed Count Display
// Description: Displays the dispensed coin amounts below AVAIL line
// Shows "DISP:XX" format for each coin type

module dispensed_count_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,

    // Coin positions (where coins are displayed)
    input wire [9:0] coin0_y_start,
    input wire [9:0] coin1_y_start,
    input wire [9:0] coin2_y_start,
    input wire [9:0] coin3_y_start, // $100 bill

    // Dispensed coin counts
    input wire [7:0] disp1_count,   // $1 coins dispensed
    input wire [7:0] disp5_count,   // $5 coins dispensed
    input wire [7:0] disp10_count,  // $10 coins dispensed
    input wire [7:0] disp100_count, // $100 bills dispensed (usually 0)

    output reg text_pixel,           // Output: 1 if text pixel should be drawn
    output reg is_disp_text_area     // Output: 1 if current position is in text area
);

// Text display parameters
localparam TEXT_X_START = 464;  // X position for text
localparam CHAR_WIDTH = 8;
localparam CHAR_HEIGHT = 16;
localparam TEXT_OFFSET_Y = 34;  // Distance below coin image
localparam LINE_SPACING = 16;   // Space between lines
localparam DISP_LINE_OFFSET = 32; // Third line: 2 * LINE_SPACING

// Calculate text Y positions for dispensed count (third line)
wire [9:0] text0_disp_y = coin0_y_start + TEXT_OFFSET_Y + DISP_LINE_OFFSET;
wire [9:0] text1_disp_y = coin1_y_start + TEXT_OFFSET_Y + DISP_LINE_OFFSET;
wire [9:0] text2_disp_y = coin2_y_start + TEXT_OFFSET_Y + DISP_LINE_OFFSET;
wire [9:0] text3_disp_y = coin3_y_start + TEXT_OFFSET_Y + DISP_LINE_OFFSET;

// Text area detection for dispensed count
// All use 7 chars "DISP:XX"
wire in_text0_disp = (pixel_y >= text0_disp_y) && (pixel_y < text0_disp_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 7 * CHAR_WIDTH);
wire in_text1_disp = (pixel_y >= text1_disp_y) && (pixel_y < text1_disp_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 7 * CHAR_WIDTH);
wire in_text2_disp = (pixel_y >= text2_disp_y) && (pixel_y < text2_disp_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 7 * CHAR_WIDTH);
wire in_text3_disp = (pixel_y >= text3_disp_y) && (pixel_y < text3_disp_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 7 * CHAR_WIDTH);

wire in_any_text_area = in_text0_disp || in_text1_disp || in_text2_disp || in_text3_disp;

// Calculate character position within text
wire [9:0] text_offset_y;
assign text_offset_y = in_text0_disp ? (pixel_y - text0_disp_y) :
                       in_text1_disp ? (pixel_y - text1_disp_y) :
                       in_text2_disp ? (pixel_y - text2_disp_y) :
                                       (pixel_y - text3_disp_y);

wire [9:0] pixel_offset_x = pixel_x - TEXT_X_START;
wire [3:0] char_index = pixel_offset_x[6:3];  // Divide by 8
wire [2:0] char_col = pixel_offset_x[2:0];    // Modulo 8
wire [3:0] char_row = text_offset_y[3:0];

// BCD conversion for dispensed counts
wire [3:0] disp1_bcd_tens, disp1_bcd_ones;
wire [3:0] disp5_bcd_tens, disp5_bcd_ones;
wire [3:0] disp10_bcd_tens, disp10_bcd_ones;
wire [3:0] disp100_bcd_tens, disp100_bcd_ones;

bin2bcd bcd_disp1 (
    .clk(clk), .reset(reset),
    .binary({8'd0, disp1_count}),
    .bcd_ones(disp1_bcd_ones),
    .bcd_tens(disp1_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_disp5 (
    .clk(clk), .reset(reset),
    .binary({8'd0, disp5_count}),
    .bcd_ones(disp5_bcd_ones),
    .bcd_tens(disp5_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_disp10 (
    .clk(clk), .reset(reset),
    .binary({8'd0, disp10_count}),
    .bcd_ones(disp10_bcd_ones),
    .bcd_tens(disp10_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_disp100 (
    .clk(clk), .reset(reset),
    .binary({8'd0, disp100_count}),
    .bcd_ones(disp100_bcd_ones),
    .bcd_tens(disp100_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

// ASCII code for current character
reg [6:0] ascii_code;

// Determine which ASCII character to display
// Format: "DISP:XX"
always @(*) begin
    if (in_any_text_area) begin
        case (char_index)
            4'd0: ascii_code = 7'h44;  // 'D'
            4'd1: ascii_code = 7'h49;  // 'I'
            4'd2: ascii_code = 7'h53;  // 'S'
            4'd3: ascii_code = 7'h50;  // 'P'
            4'd4: ascii_code = 7'h3A;  // ':'
            4'd5: begin
                if (in_text0_disp)
                    ascii_code = 7'h30 + disp1_bcd_tens;
                else if (in_text1_disp)
                    ascii_code = 7'h30 + disp5_bcd_tens;
                else if (in_text2_disp)
                    ascii_code = 7'h30 + disp10_bcd_tens;
                else
                    ascii_code = 7'h30 + disp100_bcd_tens;
            end
            4'd6: begin
                if (in_text0_disp)
                    ascii_code = 7'h30 + disp1_bcd_ones;
                else if (in_text1_disp)
                    ascii_code = 7'h30 + disp5_bcd_ones;
                else if (in_text2_disp)
                    ascii_code = 7'h30 + disp10_bcd_ones;
                else
                    ascii_code = 7'h30 + disp100_bcd_ones;
            end
            default: ascii_code = 7'h20;  // Space
        endcase
    end else begin
        ascii_code = 7'h20;  // Space
    end
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
    is_disp_text_area <= in_any_text_area;

    if (in_any_text_area) begin
        text_pixel <= char_pixel;
    end else begin
        text_pixel <= 1'b0;
    end
end

endmodule