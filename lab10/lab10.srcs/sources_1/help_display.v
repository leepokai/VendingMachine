`timescale 1ns / 1ps

module help_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire show_help,

    output reg [11:0] rgb_out,
    output reg is_drawing
);

    // Pipeline registers
    reg [9:0] r_pixel_x, r_pixel_y;
    always @(posedge clk) begin
        if (reset) begin
            r_pixel_x <= 0;
            r_pixel_y <= 0;
        end else begin
            r_pixel_x <= pixel_x;
            r_pixel_y <= pixel_y;
        end
    end

    localparam CHAR_W = 8;
    localparam CHAR_H = 16;
    
    // Top Right Header "Sw1:Help" (Shortened)
    localparam HEAD_X = 540;
    localparam HEAD_Y = 8;
    
    // Body - Moved to 540 to avoid Coin overlap (Coins at 480-510)
    localparam BODY_X = 540;
    localparam BODY_Y = 60; // Moved up from 100
    localparam LINE_SPACING = 20;

    // Region Detection
    wire in_head = (r_pixel_y >= HEAD_Y && r_pixel_y < HEAD_Y + CHAR_H) && (r_pixel_x >= HEAD_X && r_pixel_x < HEAD_X + 8 * CHAR_W);
    
    wire in_body_line1 = show_help && (r_pixel_y >= BODY_Y) && (r_pixel_y < BODY_Y + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 9 * CHAR_W);
    wire in_body_line2 = show_help && (r_pixel_y >= BODY_Y + LINE_SPACING) && (r_pixel_y < BODY_Y + LINE_SPACING + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 10 * CHAR_W);
    wire in_body_line3 = show_help && (r_pixel_y >= BODY_Y + LINE_SPACING*2) && (r_pixel_y < BODY_Y + LINE_SPACING*2 + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 7 * CHAR_W);
    wire in_body_line4 = show_help && (r_pixel_y >= BODY_Y + LINE_SPACING*3) && (r_pixel_y < BODY_Y + LINE_SPACING*3 + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 7 * CHAR_W);
    wire in_body_line5 = show_help && (r_pixel_y >= BODY_Y + LINE_SPACING*4) && (r_pixel_y < BODY_Y + LINE_SPACING*4 + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 8 * CHAR_W);
    wire in_body_line6 = show_help && (r_pixel_y >= BODY_Y + LINE_SPACING*5) && (r_pixel_y < BODY_Y + LINE_SPACING*5 + CHAR_H) && (r_pixel_x >= BODY_X && r_pixel_x < BODY_X + 11 * CHAR_W);

    reg [6:0] ascii_code;
    reg [2:0] char_col_sel; // 0=Head, 1=Body
    
    wire [9:0] off_x_head = r_pixel_x - HEAD_X;
    wire [3:0] idx_head = off_x_head[6:3];
    
    wire [9:0] off_x_body = r_pixel_x - BODY_X;
    wire [3:0] idx_body = off_x_body[6:3];

    always @(*) begin
        ascii_code = 7'h20;
        char_col_sel = 0;
        
        if (in_head) begin
            char_col_sel = 0;
            // "Sw1:Help"
            case (idx_head)
                0: ascii_code = "S"; 1: ascii_code = "w"; 2: ascii_code = "1"; 3: ascii_code = ":";
                4: ascii_code = "H"; 5: ascii_code = "e"; 6: ascii_code = "l"; 7: ascii_code = "p";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line1) begin
            char_col_sel = 1;
            // "b3:Submit"
            case (idx_body)
                0: ascii_code = "b"; 1: ascii_code = "3"; 2: ascii_code = ":"; 3: ascii_code = "S";
                4: ascii_code = "u"; 5: ascii_code = "b"; 6: ascii_code = "m"; 7: ascii_code = "i";
                8: ascii_code = "t";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line2) begin
            char_col_sel = 1;
            // "b2:Confirm"
            case (idx_body)
                0: ascii_code = "b"; 1: ascii_code = "2"; 2: ascii_code = ":"; 3: ascii_code = "C";
                4: ascii_code = "o"; 5: ascii_code = "n"; 6: ascii_code = "f"; 7: ascii_code = "i";
                8: ascii_code = "r"; 9: ascii_code = "m";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line3) begin
            char_col_sel = 1;
            // "b1:Prev"
            case (idx_body)
                0: ascii_code = "b"; 1: ascii_code = "1"; 2: ascii_code = ":"; 3: ascii_code = "P";
                4: ascii_code = "r"; 5: ascii_code = "e"; 6: ascii_code = "v";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line4) begin
            char_col_sel = 1;
            // "b0:Next"
            case (idx_body)
                0: ascii_code = "b"; 1: ascii_code = "0"; 2: ascii_code = ":"; 3: ascii_code = "N";
                4: ascii_code = "e"; 5: ascii_code = "x"; 6: ascii_code = "t";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line5) begin
            char_col_sel = 1;
            // "s0:Avail"
            case (idx_body)
                0: ascii_code = "s"; 1: ascii_code = "0"; 2: ascii_code = ":"; 3: ascii_code = "A";
                4: ascii_code = "v"; 5: ascii_code = "a"; 6: ascii_code = "i"; 7: ascii_code = "l";
                default: ascii_code = " ";
            endcase
        end else if (in_body_line6) begin
            char_col_sel = 1;
            // "b0+1:Refund"
            case (idx_body)
                0: ascii_code = "b"; 1: ascii_code = "0"; 2: ascii_code = "+"; 3: ascii_code = "1";
                4: ascii_code = ":"; 5: ascii_code = "R"; 6: ascii_code = "e"; 7: ascii_code = "f";
                8: ascii_code = "u"; 9: ascii_code = "n"; 10: ascii_code = "d";
                default: ascii_code = " ";
            endcase
        end
    end

    wire [3:0] char_row;
    assign char_row = in_head ? (r_pixel_y - HEAD_Y) : 
                      in_body_line1 ? (r_pixel_y - BODY_Y) :
                      in_body_line2 ? (r_pixel_y - (BODY_Y + LINE_SPACING)) :
                      in_body_line3 ? (r_pixel_y - (BODY_Y + LINE_SPACING*2)) :
                      in_body_line4 ? (r_pixel_y - (BODY_Y + LINE_SPACING*3)) :
                      in_body_line5 ? (r_pixel_y - (BODY_Y + LINE_SPACING*4)) :
                                      (r_pixel_y - (BODY_Y + LINE_SPACING*5));

    wire [2:0] char_col = (char_col_sel == 0) ? off_x_head[2:0] : off_x_body[2:0];

    wire font_pixel;
    pc_vga_8x16_00_7F font_rom (
        .clk(clk),
        .ascii_code(ascii_code),
        .row(char_row),
        .col(char_col),
        .row_of_pixels(font_pixel)
    );

    always @(*) begin
        is_drawing = 0;
        rgb_out = 0;
        if ((in_head || in_body_line1 || in_body_line2 || in_body_line3 || in_body_line4 || in_body_line5 || in_body_line6) && font_pixel) begin
            is_drawing = 1;
            rgb_out = 12'hFFF;
        end
    end

endmodule