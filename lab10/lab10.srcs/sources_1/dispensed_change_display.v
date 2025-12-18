`timescale 1ns / 1ps

module dispensed_change_display (
    input wire clk,
    input wire reset,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,

    // Dispensed coin counts
    input wire [7:0] disp1_count,
    input wire [7:0] disp5_count,
    input wire [7:0] disp10_count,
    input wire [7:0] disp100_count,

    output reg [11:0] rgb_out,
    output reg is_drawing
);

    // Transparency color
    localparam TRANSPARENT = 12'h0F0;

    // Layout parameters
    localparam START_X = 8;
    localparam START_Y = 60; 
    localparam LINE_HEIGHT = 30; // Increased spacing
    localparam ICON_W = 20;
    localparam ICON_H = 20;
    localparam BILL_W = 20;
    localparam BILL_H = 10;
    
    // Text layout
    localparam TEXT_OFFSET_X = 24; // Icon (20) + Padding (4)
    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 16;
    
    // Visibility
    wire show1 = (disp1_count > 0);
    wire show5 = (disp5_count > 0);
    wire show10 = (disp10_count > 0);
    wire show100 = (disp100_count > 0);

    // Y Positions
    wire [9:0] line_dispensed_y = START_Y;
    wire [9:0] line1_y = START_Y + LINE_HEIGHT;
    wire [9:0] line5_y = line1_y + (show1 ? LINE_HEIGHT : 0);
    wire [9:0] line10_y = line5_y + (show5 ? LINE_HEIGHT : 0);
    wire [9:0] line100_y = line10_y + (show10 ? LINE_HEIGHT : 0);

    // Pipeline Stage 1: Address Calculation & Region Detection
    reg [9:0] r_pixel_x, r_pixel_y;
    reg [8:0] coin_addr;
    reg [2:0] r_coin_sel; // 0=None, 1=Coin1, 2=Coin5, 3=Coin10, 4=Coin100
    
    reg in_header_region;
    reg in_text_region;
    reg [2:0] text_line_sel; // 0=Header, 1=Line1, 2=Line5, 3=Line10, 4=Line100
    
    always @(posedge clk) begin
        if (reset) begin
            r_pixel_x <= 0;
            r_pixel_y <= 0;
            coin_addr <= 0;
            r_coin_sel <= 0;
            in_header_region <= 0;
            in_text_region <= 0;
            text_line_sel <= 0;
        end else begin
            r_pixel_x <= pixel_x;
            r_pixel_y <= pixel_y;
            
            // Icon Detection & Address Gen
            if (pixel_x >= START_X && pixel_x < START_X + ICON_W) begin
                if (show1 && pixel_y >= line1_y && pixel_y < line1_y + ICON_H) begin
                    r_coin_sel <= 1;
                    coin_addr <= (pixel_y - line1_y) * 20 + (pixel_x - START_X);
                end else if (show5 && pixel_y >= line5_y && pixel_y < line5_y + ICON_H) begin
                    r_coin_sel <= 2;
                    coin_addr <= (pixel_y - line5_y) * 20 + (pixel_x - START_X);
                end else if (show10 && pixel_y >= line10_y && pixel_y < line10_y + ICON_H) begin
                    r_coin_sel <= 3;
                    coin_addr <= (pixel_y - line10_y) * 20 + (pixel_x - START_X);
                end else if (show100 && pixel_y >= line100_y + 5 && pixel_y < line100_y + 5 + BILL_H) begin // Center bill
                    r_coin_sel <= 4;
                    coin_addr <= (pixel_y - (line100_y + 5)) * 20 + (pixel_x - START_X);
                end else begin
                    r_coin_sel <= 0;
                    coin_addr <= 0;
                end
            end else begin
                r_coin_sel <= 0;
                coin_addr <= 0;
            end

            // Text Region Detection
            // Header: "Dispensed" at START_X
            if (pixel_y >= line_dispensed_y && pixel_y < line_dispensed_y + CHAR_HEIGHT && 
                pixel_x >= START_X && pixel_x < START_X + 9 * CHAR_WIDTH) begin
                in_header_region <= 1;
                text_line_sel <= 0;
            end else begin
                in_header_region <= 0;
                // Quantity Text: "x NN" at START_X + TEXT_OFFSET_X (4 chars wide)
                if (pixel_x >= START_X + TEXT_OFFSET_X && pixel_x < START_X + TEXT_OFFSET_X + 4 * CHAR_WIDTH) begin
                    if (show1 && pixel_y >= line1_y && pixel_y < line1_y + CHAR_HEIGHT) begin
                        in_text_region <= 1; text_line_sel <= 1;
                    end else if (show5 && pixel_y >= line5_y && pixel_y < line5_y + CHAR_HEIGHT) begin
                        in_text_region <= 1; text_line_sel <= 2;
                    end else if (show10 && pixel_y >= line10_y && pixel_y < line10_y + CHAR_HEIGHT) begin
                        in_text_region <= 1; text_line_sel <= 3;
                    end else if (show100 && pixel_y >= line100_y && pixel_y < line100_y + CHAR_HEIGHT) begin
                        in_text_region <= 1; text_line_sel <= 4;
                    end else begin
                        in_text_region <= 0; text_line_sel <= 0;
                    end
                end else begin
                    in_text_region <= 0; text_line_sel <= 0;
                end
            end
        end
    end

    // Pipeline Stage 2: Memory Read & Char Gen
    // SRAMs
    wire [11:0] data1, data5, data10, data100;
    
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(400), .MEM_INIT_FILE("Coin1.mem"))
        ram1 (.clk(clk), .we(1'b0), .en(1'b1), .addr(coin_addr), .data_i(12'h000), .data_o(data1));
        
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(400), .MEM_INIT_FILE("Coin5.mem"))
        ram5 (.clk(clk), .we(1'b0), .en(1'b1), .addr(coin_addr), .data_i(12'h000), .data_o(data5));
        
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(400), .MEM_INIT_FILE("Coin10.mem"))
        ram10 (.clk(clk), .we(1'b0), .en(1'b1), .addr(coin_addr), .data_i(12'h000), .data_o(data10));
        
    sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(200), .MEM_INIT_FILE("Dollar100.mem"))
        ram100 (.clk(clk), .we(1'b0), .en(1'b1), .addr(coin_addr), .data_i(12'h000), .data_o(data100));

    wire [3:0] bcd1_tens, bcd1_ones;
    wire [3:0] bcd5_tens, bcd5_ones;
    wire [3:0] bcd10_tens, bcd10_ones;
    wire [3:0] bcd100_tens, bcd100_ones;

    bin2bcd bcd1 (.clk(clk), .reset(reset), .binary({8'd0, disp1_count}), .bcd_ones(bcd1_ones), .bcd_tens(bcd1_tens));
    bin2bcd bcd5 (.clk(clk), .reset(reset), .binary({8'd0, disp5_count}), .bcd_ones(bcd5_ones), .bcd_tens(bcd5_tens));
    bin2bcd bcd10 (.clk(clk), .reset(reset), .binary({8'd0, disp10_count}), .bcd_ones(bcd10_ones), .bcd_tens(bcd10_tens));
    bin2bcd bcd100 (.clk(clk), .reset(reset), .binary({8'd0, disp100_count}), .bcd_ones(bcd100_ones), .bcd_tens(bcd100_tens));

    // Char Selection
    reg [6:0] ascii_code;
    
    wire [9:0] pixel_offset_x_header = r_pixel_x - START_X;
    wire [3:0] char_index_header = pixel_offset_x_header[6:3];
    
    wire [9:0] pixel_offset_x_text = r_pixel_x - (START_X + TEXT_OFFSET_X);
    wire [3:0] char_index_text = pixel_offset_x_text[6:3];
    
    always @(*) begin
        ascii_code = 7'h20;
        if (in_header_region) begin
            case (char_index_header)
                0: ascii_code = "D"; 1: ascii_code = "i"; 2: ascii_code = "s"; 3: ascii_code = "p";
                4: ascii_code = "e"; 5: ascii_code = "n"; 6: ascii_code = "s"; 7: ascii_code = "e";
                8: ascii_code = "d"; default: ascii_code = " ";
            endcase
        end else if (in_text_region) begin
            case (char_index_text)
                0: ascii_code = "x";
                1: ascii_code = " "; // Added space
                2: begin
                   case (text_line_sel)
                       1: ascii_code = 7'h30 + bcd1_tens;
                       2: ascii_code = 7'h30 + bcd5_tens;
                       3: ascii_code = 7'h30 + bcd10_tens;
                       4: ascii_code = 7'h30 + bcd100_tens;
                       default: ascii_code = " ";
                   endcase
                end
                3: begin
                   case (text_line_sel)
                       1: ascii_code = 7'h30 + bcd1_ones;
                       2: ascii_code = 7'h30 + bcd5_ones;
                       3: ascii_code = 7'h30 + bcd10_ones;
                       4: ascii_code = 7'h30 + bcd100_ones;
                       default: ascii_code = " ";
                   endcase
                end
                default: ascii_code = " ";
            endcase
        end
    end

    wire [2:0] char_col = (in_header_region) ? pixel_offset_x_header[2:0] : pixel_offset_x_text[2:0];
    
    reg [9:0] current_line_y;
    always @(*) begin
        case (text_line_sel)
            0: current_line_y = line_dispensed_y;
            1: current_line_y = line1_y;
            2: current_line_y = line5_y;
            3: current_line_y = line10_y;
            4: current_line_y = line100_y;
            default: current_line_y = 0;
        endcase
    end
    wire [3:0] char_row = r_pixel_y - current_line_y;

    wire font_pixel;
    pc_vga_8x16_00_7F font_rom (
        .clk(clk),
        .ascii_code(ascii_code),
        .row(char_row),
        .col(char_col),
        .row_of_pixels(font_pixel)
    );

    // Output MUX (Stage 3 - Combinational)
    always @(*) begin
        is_drawing = 0;
        rgb_out = 0;

        // Priority to Icons
        if (r_coin_sel != 0) begin
            case (r_coin_sel)
                1: if (data1 != TRANSPARENT) begin is_drawing = 1; rgb_out = data1; end
                2: if (data5 != TRANSPARENT) begin is_drawing = 1; rgb_out = data5; end
                3: if (data10 != TRANSPARENT) begin is_drawing = 1; rgb_out = data10; end
                4: if (data100 != TRANSPARENT) begin is_drawing = 1; rgb_out = data100; end
            endcase
        end 
        // Then Text
        else if (in_header_region || in_text_region) begin
            if (font_pixel) begin
                is_drawing = 1;
                rgb_out = 12'hFFF;
            end
        end
    end

endmodule