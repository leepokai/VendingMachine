// coin_count_display.v
// Module: Coin Count Display
// Description: Displays the count of each coin type below the coin images
// Shows two lines per coin:
//   Line 1: "X:NN" (inserted count)
//   Line 2: "AVAIL:NN" (available in machine)

module coin_count_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,

    // Coin positions (where coins are displayed)
    input wire [9:0] coin0_y_start,
    input wire [9:0] coin1_y_start,
    input wire [9:0] coin2_y_start,

    // Coin counts to display (inserted)
    input wire [7:0] coin1_count,   // $1 coins inserted
    input wire [7:0] coin5_count,   // $5 coins inserted
    input wire [7:0] coin10_count,  // $10 coins inserted

    // Available coin counts (machine inventory)
    input wire [7:0] avail1_count,  // $1 coins available
    input wire [7:0] avail5_count,  // $5 coins available
    input wire [7:0] avail10_count, // $10 coins available

    output reg text_pixel,           // Output: 1 if text pixel should be drawn
    output reg is_coin_text_area     // Output: 1 if current position is in text area
);

// Text display parameters
localparam TEXT_X_START = 464;  // X position for text
localparam CHAR_WIDTH = 8;
localparam CHAR_HEIGHT = 16;
localparam TEXT_OFFSET_Y = 24;  // Distance below coin image (20px coin + 4px gap)
localparam LINE_SPACING = 16;   // Space between two text lines

// Calculate text Y positions for each coin (first line - inserted count)
wire [9:0] text0_line1_y = coin0_y_start + TEXT_OFFSET_Y;
wire [9:0] text1_line1_y = coin1_y_start + TEXT_OFFSET_Y;
wire [9:0] text2_line1_y = coin2_y_start + TEXT_OFFSET_Y;

// Second line - AVAIL count
wire [9:0] text0_line2_y = text0_line1_y + LINE_SPACING;
wire [9:0] text1_line2_y = text1_line1_y + LINE_SPACING;
wire [9:0] text2_line2_y = text2_line1_y + LINE_SPACING;

// Text area detection for inserted count (line 1)
// Coin 0 ($1):  4 chars "1:XX"
// Coin 1 ($5):  4 chars "5:XX"
// Coin 2 ($10): 5 chars "10:XX"
wire in_text0_line1 = (pixel_y >= text0_line1_y) && (pixel_y < text0_line1_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 4 * CHAR_WIDTH);
wire in_text1_line1 = (pixel_y >= text1_line1_y) && (pixel_y < text1_line1_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 4 * CHAR_WIDTH);
wire in_text2_line1 = (pixel_y >= text2_line1_y) && (pixel_y < text2_line1_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 5 * CHAR_WIDTH);

// Text area detection for AVAIL count (line 2)
// All use 8 chars "AVAIL:XX"
wire in_text0_line2 = (pixel_y >= text0_line2_y) && (pixel_y < text0_line2_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 8 * CHAR_WIDTH);
wire in_text1_line2 = (pixel_y >= text1_line2_y) && (pixel_y < text1_line2_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 8 * CHAR_WIDTH);
wire in_text2_line2 = (pixel_y >= text2_line2_y) && (pixel_y < text2_line2_y + CHAR_HEIGHT) &&
                      (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 8 * CHAR_WIDTH);

wire in_any_text_area = in_text0_line1 || in_text1_line1 || in_text2_line1 ||
                        in_text0_line2 || in_text1_line2 || in_text2_line2;

// Calculate character position within text
wire [9:0] text_offset_y;
assign text_offset_y = in_text0_line1 ? (pixel_y - text0_line1_y) :
                       in_text1_line1 ? (pixel_y - text1_line1_y) :
                       in_text2_line1 ? (pixel_y - text2_line1_y) :
                       in_text0_line2 ? (pixel_y - text0_line2_y) :
                       in_text1_line2 ? (pixel_y - text1_line2_y) :
                                        (pixel_y - text2_line2_y);

wire [9:0] pixel_offset_x = pixel_x - TEXT_X_START;
wire [3:0] char_index = pixel_offset_x[6:3];  // Divide by 8
wire [2:0] char_col = pixel_offset_x[2:0];    // Modulo 8
wire [3:0] char_row = text_offset_y[3:0];

// BCD conversion for inserted coin counts
wire [3:0] coin1_bcd_tens, coin1_bcd_ones;
wire [3:0] coin5_bcd_tens, coin5_bcd_ones;
wire [3:0] coin10_bcd_tens, coin10_bcd_ones;

bin2bcd bcd_coin1 (
    .clk(clk), .reset(reset),
    .binary({8'd0, coin1_count}),
    .bcd_ones(coin1_bcd_ones),
    .bcd_tens(coin1_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_coin5 (
    .clk(clk), .reset(reset),
    .binary({8'd0, coin5_count}),
    .bcd_ones(coin5_bcd_ones),
    .bcd_tens(coin5_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_coin10 (
    .clk(clk), .reset(reset),
    .binary({8'd0, coin10_count}),
    .bcd_ones(coin10_bcd_ones),
    .bcd_tens(coin10_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

// BCD conversion for available coin counts
wire [3:0] avail1_bcd_tens, avail1_bcd_ones;
wire [3:0] avail5_bcd_tens, avail5_bcd_ones;
wire [3:0] avail10_bcd_tens, avail10_bcd_ones;

bin2bcd bcd_avail1 (
    .clk(clk), .reset(reset),
    .binary({8'd0, avail1_count}),
    .bcd_ones(avail1_bcd_ones),
    .bcd_tens(avail1_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_avail5 (
    .clk(clk), .reset(reset),
    .binary({8'd0, avail5_count}),
    .bcd_ones(avail5_bcd_ones),
    .bcd_tens(avail5_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

bin2bcd bcd_avail10 (
    .clk(clk), .reset(reset),
    .binary({8'd0, avail10_count}),
    .bcd_ones(avail10_bcd_ones),
    .bcd_tens(avail10_bcd_tens),
    .bcd_hundreds(),
    .bcd_thousands()
);

// ASCII code for current character
reg [6:0] ascii_code;

// Determine which ASCII character to display
always @(*) begin
    // Line 1: Inserted count
    if (in_text0_line1 || in_text1_line1) begin
        // For $1 and $5: 4 characters "1:XX" or "5:XX"
        case (char_index)
            4'd0: begin
                if (in_text0_line1)
                    ascii_code = 7'h31;  // '1'
                else
                    ascii_code = 7'h35;  // '5'
            end
            4'd1: ascii_code = 7'h3A;  // ':'
            4'd2: ascii_code = 7'h30 + (in_text0_line1 ? coin1_bcd_tens : coin5_bcd_tens);
            4'd3: ascii_code = 7'h30 + (in_text0_line1 ? coin1_bcd_ones : coin5_bcd_ones);
            default: ascii_code = 7'h20;  // Space
        endcase
    end else if (in_text2_line1) begin
        // For $10: 5 characters "10:XX"
        case (char_index)
            4'd0: ascii_code = 7'h31;  // '1'
            4'd1: ascii_code = 7'h30;  // '0'
            4'd2: ascii_code = 7'h3A;  // ':'
            4'd3: ascii_code = 7'h30 + coin10_bcd_tens;
            4'd4: ascii_code = 7'h30 + coin10_bcd_ones;
            default: ascii_code = 7'h20;  // Space
        endcase
    end
    // Line 2: AVAIL count
    else if (in_text0_line2 || in_text1_line2 || in_text2_line2) begin
        // All use 8 characters "AVAIL:XX"
        case (char_index)
            4'd0: ascii_code = 7'h41;  // 'A'
            4'd1: ascii_code = 7'h56;  // 'V'
            4'd2: ascii_code = 7'h41;  // 'A'
            4'd3: ascii_code = 7'h49;  // 'I'
            4'd4: ascii_code = 7'h4C;  // 'L'
            4'd5: ascii_code = 7'h3A;  // ':'
            4'd6: begin
                if (in_text0_line2)
                    ascii_code = 7'h30 + avail1_bcd_tens;
                else if (in_text1_line2)
                    ascii_code = 7'h30 + avail5_bcd_tens;
                else
                    ascii_code = 7'h30 + avail10_bcd_tens;
            end
            4'd7: begin
                if (in_text0_line2)
                    ascii_code = 7'h30 + avail1_bcd_ones;
                else if (in_text1_line2)
                    ascii_code = 7'h30 + avail5_bcd_ones;
                else
                    ascii_code = 7'h30 + avail10_bcd_ones;
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
    is_coin_text_area <= in_any_text_area;

    if (in_any_text_area) begin
        text_pixel <= char_pixel;
    end else begin
        text_pixel <= 1'b0;
    end
end

endmodule
