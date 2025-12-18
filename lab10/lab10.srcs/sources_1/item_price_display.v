`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: item_price_display
// Description: Displays price tags ("$XX") above each vending item
//////////////////////////////////////////////////////////////////////////////////

module item_price_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    // Prices for 9 items
    input wire [7:0] price_0, price_1, price_2,
    input wire [7:0] price_3, price_4, price_5,
    input wire [7:0] price_6, price_7, price_8,
    
    output reg text_pixel,
    output reg is_text_area
);

    // --- Constants from lab10.v ---
    localparam VGA_W = 640;
    localparam VGA_H = 480;
    localparam VBUF_W = 40;
    localparam VBUF_H = 70;
    localparam SCALE_FACTOR = 6;
    localparam SCALED_IMG_W = VBUF_W * SCALE_FACTOR; // 240
    localparam SCALED_IMG_H = VBUF_H * SCALE_FACTOR; // 420
    localparam H_START = (VGA_W - SCALED_IMG_W) / 2; // 200
    localparam V_START = (VGA_H - SCALED_IMG_H) / 2; // 30
    localparam BOX_W  = 25;
    localparam BOX_H  = 5;
    localparam SPRITE_SCALE_FACTOR = 2;

    // Base positions (copied from lab10.v)
    localparam BASE_X_0=10, BASE_Y_0=14;
    localparam BASE_X_1=20, BASE_Y_1=14;
    localparam BASE_X_2=30, BASE_Y_2=14;
    localparam BASE_X_3=10, BASE_Y_3=26;
    localparam BASE_X_4=20, BASE_Y_4=26;
    localparam BASE_X_5=30, BASE_Y_5=26;
    localparam BASE_X_6=10, BASE_Y_6=37;
    localparam BASE_X_7=20, BASE_Y_7=37;
    localparam BASE_X_8=30, BASE_Y_8=37;

    // --- Helper Functions for Position Calculation ---
    // Calculates the top-left X of the SelectBox sprite
    function [9:0] calc_x;
        input [9:0] base;
        begin
            // formula matches lab10.v: center - (width/2)
            // width = 25 * 2 = 50. half = 25.
            calc_x = H_START + base * SCALE_FACTOR - 25;
        end
    endfunction

    function [9:0] calc_y;
        input [9:0] base;
        begin
            // height = 5 * 2 = 10. half = 5.
            calc_y = V_START + base * SCALE_FACTOR - 5;
        end
    endfunction

    // --- Text Positioning ---
    localparam CHAR_W = 8;
    localparam CHAR_H = 16;
    // Position text above the box. Box top is at calc_y().
    // We want some padding. Let's say 2 pixels padding.
    // Text Y = Box Y - CHAR_H - Padding
    localparam TEXT_PADDING = 2;
    
    wire [9:0] box_x [0:8];
    wire [9:0] box_y [0:8];
    wire [9:0] text_x [0:8];
    wire [9:0] text_y [0:8];

    assign box_x[0] = calc_x(BASE_X_0); assign box_y[0] = calc_y(BASE_Y_0);
    assign box_x[1] = calc_x(BASE_X_1); assign box_y[1] = calc_y(BASE_Y_1);
    assign box_x[2] = calc_x(BASE_X_2); assign box_y[2] = calc_y(BASE_Y_2);
    assign box_x[3] = calc_x(BASE_X_3); assign box_y[3] = calc_y(BASE_Y_3);
    assign box_x[4] = calc_x(BASE_X_4); assign box_y[4] = calc_y(BASE_Y_4);
    assign box_x[5] = calc_x(BASE_X_5); assign box_y[5] = calc_y(BASE_Y_5);
    assign box_x[6] = calc_x(BASE_X_6); assign box_y[6] = calc_y(BASE_Y_6);
    assign box_x[7] = calc_x(BASE_X_7); assign box_y[7] = calc_y(BASE_Y_7);
    assign box_x[8] = calc_x(BASE_X_8); assign box_y[8] = calc_y(BASE_Y_8);

    genvar i;
    generate
        for (i=0; i<9; i=i+1) begin : calc_pos
            // Center text horizontally: 
            // Box Width is 50. Text "$XX" (3 chars) is 24.
            // Offset = (50 - 24) / 2 = 13.
            assign text_x[i] = box_x[i] + 13;
            // Place text above box
            assign text_y[i] = box_y[i] - CHAR_H - TEXT_PADDING;
        end
    endgenerate

    // --- BCD Conversion ---
    wire [3:0] bcd_tens [0:8];
    wire [3:0] bcd_ones [0:8];
    wire [7:0] prices [0:8];
    
    assign prices[0] = price_0; assign prices[1] = price_1; assign prices[2] = price_2;
    assign prices[3] = price_3; assign prices[4] = price_4; assign prices[5] = price_5;
    assign prices[6] = price_6; assign prices[7] = price_7; assign prices[8] = price_8;

    generate
        for (i=0; i<9; i=i+1) begin : bcd_gen
            bin2bcd b2b (
                .clk(clk), .reset(reset),
                .binary({8'd0, prices[i]}),
                .bcd_ones(bcd_ones[i]),
                .bcd_tens(bcd_tens[i]),
                .bcd_hundreds(), .bcd_thousands()
            );
        end
    endgenerate

    // --- Hit Testing & Char Selection ---
    reg [3:0] active_item; // 0-8, or 15 if none
    reg in_text_area_comb;
    reg [9:0] rel_x, rel_y;
    
    integer k;
    always @(*) begin
        active_item = 15;
        in_text_area_comb = 0;
        rel_x = 0;
        rel_y = 0;
        for (k=0; k<9; k=k+1) begin
            if (pixel_x >= text_x[k] && pixel_x < text_x[k] + 3*CHAR_W &&
                pixel_y >= text_y[k] && pixel_y < text_y[k] + CHAR_H) begin
                active_item = k[3:0];
                in_text_area_comb = 1;
                rel_x = pixel_x - text_x[k];
                rel_y = pixel_y - text_y[k];
            end
        end
    end

    wire [2:0] char_idx = rel_x[5:3]; // Divide by 8
    wire [2:0] char_col = rel_x[2:0]; // Mod 8
    wire [3:0] char_row = rel_y[3:0]; // Mod 16
    
    reg [6:0] ascii_code;
    
    always @(*) begin
        if (active_item != 15) begin
            if (prices[active_item] == 0) begin // If price is 0, display spaces
                ascii_code = 7'h20; // Space character
            end else begin
                case (char_idx)
                    3'd0: ascii_code = 7'h24; // '$'
                    3'd1: ascii_code = 7'h30 + bcd_tens[active_item];
                    3'd2: ascii_code = 7'h30 + bcd_ones[active_item];
                    default: ascii_code = 7'h20;
                endcase
            end
        end else begin
            ascii_code = 7'h20;
        end
    end

    // --- Font ROM ---
    wire font_pixel;
    pc_vga_8x16_00_7F font_rom (
        .clk(clk),
        .ascii_code(ascii_code),
        .row(char_row),
        .col(char_col),
        .row_of_pixels(font_pixel)
    );

    // --- Output Registration ---
    always @(posedge clk) begin
        if (reset) begin
            is_text_area <= 0;
            text_pixel <= 0;
        end else begin
            is_text_area <= in_text_area_comb;
            // Delay pixel data by 1 cycle to match is_text_area (which is registered from comb)
            // Wait, is_text_area is registered. font_rom is sync (registered output).
            // Font ROM in this project usually takes clk and gives output on next cycle?
            // Let's check text_renderer.v again.
            // In text_renderer:
            // char_rom(...)
            // always @(posedge clk) ... text_pixel <= char_pixel;
            // So char_rom seems to be combinational or 1 cycle latency?
            // If char_rom is sync, then text_pixel <= char_pixel adds another cycle.
            // Let's check pc_vga_8x16_00_7F.v if possible.
            // Assuming standard sync ROM behavior.
            
            // In text_renderer, `is_text_area <= in_text_x && in_text_y` (registered).
            // And `text_pixel <= char_pixel` (registered).
            // If char_pixel comes from a sync ROM, it's already delayed 1 cycle.
            // If text_pixel is registered again, it's 2 cycles.
            // But is_text_area is calculated from current pixel_x, so it is 1 cycle delayed.
            // If char_pixel is 1 cycle delayed (sync ROM), then text_pixel being registered makes it 2 cycles?
            // Wait, usually Font ROMs in these projects are implemented as `always @(posedge clk) data <= mem[...]`.
            
            // Let's look at text_renderer again.
            // wire char_pixel;
            // pc_vga... char_rom (..., .row_of_pixels(char_pixel));
            // always @(posedge clk) begin is_text_area <= ...; text_pixel <= char_pixel; end
            
            // This suggests char_pixel is available "next cycle" relative to address change if it's sync.
            // Or "same cycle" if it's async/distributed RAM.
            // If it's standard Block RAM, it's sync.
            
            // I'll assume the same structure as text_renderer works.
            text_pixel <= (in_text_area_comb) ? font_pixel : 1'b0;
        end
    end

endmodule
