`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: Refund Text Renderer
// Description: Displays "REFUND" or "FAILED" in the vending machine exit area
//////////////////////////////////////////////////////////////////////////////////

module refund_text_renderer (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire refund_active,       // High when message should be shown
    input wire refund_reason,       // 0 = Manual Refund ("REFUND"), 1 = Error/No Change ("FAILED")
    output reg text_pixel,          // Output: 1 if text pixel should be drawn
    output reg is_text_area         // Output: 1 if current position is in text area
);

// Display parameters (Centered in the exit area: X~296, Y~373)
localparam TEXT_X_START = 296;
localparam TEXT_Y_START = 373;
localparam CHAR_WIDTH = 8;
localparam CHAR_HEIGHT = 16;
localparam NUM_CHARS = 6;  // Both "REFUND" and "FAILED" are 6 chars

wire in_text_x = (pixel_x >= TEXT_X_START) && (pixel_x < TEXT_X_START + NUM_CHARS * CHAR_WIDTH);
wire in_text_y = (pixel_y >= TEXT_Y_START) && (pixel_y < TEXT_Y_START + CHAR_HEIGHT);

// Calculate character index
wire [9:0] pixel_offset_x = pixel_x - TEXT_X_START;
wire [3:0] char_index = pixel_offset_x[6:3]; // Divide by 8
wire [2:0] char_col = pixel_offset_x[2:0];   // Modulo 8
wire [3:0] char_row = pixel_y - TEXT_Y_START;

// ASCII code selection
reg [6:0] ascii_code;

always @(*) begin
    if (refund_reason == 1'b0) begin
        // Case 0: "REFUND"
        case (char_index)
            4'd0: ascii_code = 7'h52; // 'R'
            4'd1: ascii_code = 7'h45; // 'E'
            4'd2: ascii_code = 7'h46; // 'F'
            4'd3: ascii_code = 7'h55; // 'U'
            4'd4: ascii_code = 7'h4E; // 'N'
            4'd5: ascii_code = 7'h44; // 'D'
            default: ascii_code = 7'h20; // Space
        endcase
    end else begin
        // Case 1: "FAILED"
        case (char_index)
            4'd0: ascii_code = 7'h46; // 'F'
            4'd1: ascii_code = 7'h41; // 'A'
            4'd2: ascii_code = 7'h49; // 'I'
            4'd3: ascii_code = 7'h4C; // 'L'
            4'd4: ascii_code = 7'h45; // 'E'
            4'd5: ascii_code = 7'h44; // 'D'
            default: ascii_code = 7'h20; // Space
        endcase
    end
end

// Instantiate character ROM (Shared/Standard 8x16 font)
wire char_pixel;

pc_vga_8x16_00_7F char_rom_inst (
    .clk(clk),
    .ascii_code(ascii_code),
    .row(char_row),
    .col(char_col),
    .row_of_pixels(char_pixel)
);

// Output logic
always @(posedge clk) begin
    if (reset) begin
        is_text_area <= 1'b0;
        text_pixel <= 1'b0;
    end else begin
        // Only active if refund_active is high AND we are in the box
        is_text_area <= in_text_x && in_text_y && refund_active;
        
        if (in_text_x && in_text_y && refund_active) begin
            text_pixel <= char_pixel;
        end else begin
            text_pixel <= 1'b0;
        end
    end
end

endmodule
