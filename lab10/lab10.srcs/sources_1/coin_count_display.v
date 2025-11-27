// coin_count_display.v
// Module: Coin Count Display
// Description: Displays the count of each coin type below the coin images
// Shows "X: NN" format where X is coin type and NN is count

module coin_count_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,

    // Coin positions (where coins are displayed)
    input wire [9:0] coin0_y_start,
    input wire [9:0] coin1_y_start,
    input wire [9:0] coin2_y_start,

    // Coin counts to display
    input wire [7:0] coin1_count,   // $1 coins
    input wire [7:0] coin5_count,   // $5 coins
    input wire [7:0] coin10_count,  // $10 coins

    output reg text_pixel,           // Output: 1 if text pixel should be drawn
    output reg is_coin_text_area     // Output: 1 if current position is in text area
);

// Text display parameters
localparam TEXT_X_START = 472;  // Slightly left of coin to center text
localparam CHAR_WIDTH = 8;
localparam CHAR_HEIGHT = 16;
localparam TEXT_OFFSET_Y = 24;  // Distance below coin image (20px coin + 4px gap)

// Calculate text Y positions for each coin
wire [9:0] text0_y = coin0_y_start + TEXT_OFFSET_Y;
wire [9:0] text1_y = coin1_y_start + TEXT_OFFSET_Y;
wire [9:0] text2_y = coin2_y_start + TEXT_OFFSET_Y;

// Text area widths (different for each coin)
// Coin 0 ($1):  4 chars "1:XX"
// Coin 1 ($5):  4 chars "5:XX"
// Coin 2 ($10): 5 chars "10:XX"
wire in_text0_area = (pixel_y >= text0_y) && (pixel_y < text0_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 4 * CHAR_WIDTH);
wire in_text1_area = (pixel_y >= text1_y) && (pixel_y < text1_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 4 * CHAR_WIDTH);
wire in_text2_area = (pixel_y >= text2_y) && (pixel_y < text2_y + CHAR_HEIGHT) &&
                     (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + 5 * CHAR_WIDTH);

wire in_any_text_area = in_text0_area || in_text1_area || in_text2_area;

// Calculate character position within text
wire [9:0] text_offset_y;
assign text_offset_y = in_text0_area ? (pixel_y - text0_y) :
                       in_text1_area ? (pixel_y - text1_y) :
                                       (pixel_y - text2_y);

wire [9:0] pixel_offset_x = pixel_x - TEXT_X_START;
wire [2:0] char_index = pixel_offset_x[5:3];  // Divide by 8 (4 chars: "1:XX")
wire [2:0] char_col = pixel_offset_x[2:0];    // Modulo 8
wire [3:0] char_row = text_offset_y[3:0];

// BCD conversion for coin counts
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

// ASCII code for current character
reg [6:0] ascii_code;

// Select which count to display
wire [3:0] current_tens = in_text0_area ? coin1_bcd_tens :
                          in_text1_area ? coin5_bcd_tens :
                                          coin10_bcd_tens;
wire [3:0] current_ones = in_text0_area ? coin1_bcd_ones :
                          in_text1_area ? coin5_bcd_ones :
                                          coin10_bcd_ones;

// Determine which ASCII character to display
// Format: "1:XX", "5:XX", "10:XX" where XX is the count
always @(*) begin
    if (in_text0_area || in_text1_area) begin
        // For $1 and $5: 4 characters "1:XX" or "5:XX"
        case (char_index)
            3'd0: begin  // Coin denomination
                if (in_text0_area)
                    ascii_code = 7'h31;  // '1'
                else
                    ascii_code = 7'h35;  // '5'
            end
            3'd1: ascii_code = 7'h3A;  // ':'
            3'd2: ascii_code = 7'h30 + current_tens;   // Tens digit
            3'd3: ascii_code = 7'h30 + current_ones;   // Ones digit
            default: ascii_code = 7'h20;  // Space
        endcase
    end else begin
        // For $10: 5 characters "10:XX"
        case (char_index)
            3'd0: ascii_code = 7'h31;  // '1'
            3'd1: ascii_code = 7'h30;  // '0'
            3'd2: ascii_code = 7'h3A;  // ':'
            3'd3: ascii_code = 7'h30 + current_tens;   // Tens digit
            3'd4: ascii_code = 7'h30 + current_ones;   // Ones digit
            default: ascii_code = 7'h20;  // Space
        endcase
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
