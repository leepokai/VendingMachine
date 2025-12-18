`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cart_list_renderer
// Description: Renders the shopping list in the bottom-right corner.
//              Stacks items from bottom to top.
//              Format: [Icon 60x60] [Text: x N]
//              Background: Black for active list items.
//////////////////////////////////////////////////////////////////////////////////

module cart_list_renderer (
    input wire clk,
    input wire reset,
    
    // VGA Interface
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    
    // Data from SRAM (Muxed in lab10.v based on item_id_out)
    input wire [11:0] sram_data,
    
    // Update Interface
    input wire update_trigger,      // Pulse: Add/Update item count
    input wire clear_list,          // Pulse: Clear the list (New Transaction)
    input wire [3:0] item_index,    // Which item to update (0-8)
    
    // Outputs
    output reg [11:0] rgb_out,
    output reg is_drawing,          // Active when pixel is within list graphics
    output reg [9:0] target_y_pos,  // Where the animation should fly to
    
    // Memory Read Interface
    output reg [9:0] ram_addr,      // Calculated address for SRAM
    output reg [3:0] item_id_out,   // Which item is at current pixel (for MUX)
    output reg is_reading_ram       // High if we need SRAM data for this pixel
);

    // --- Configuration ---
    localparam START_X = 530;       // X position of the list (Shifted right)
    localparam ICON_WIDTH = 60;     // Scaled width (10 * 6)
    localparam ICON_HEIGHT = 60;    // Scaled height (10 * 6)
    localparam PADDING = 4;         // Gap between icon and text
    localparam ROW_HEIGHT = 60;     // Height of each row (same as icon)
    localparam BOTTOM_Y = 400;      // Y position of the FIRST item (bottom-most) - Moved up slightly
    localparam MAX_ITEMS = 6;       // Max items to fit
    localparam TRANSPARENT_COLOR = 12'h0F0; // Green screen color
    
    localparam TEXT_OFFSET_X = ICON_WIDTH + PADDING;
    localparam LIST_WIDTH = 110;    // Width of the black background box (Icon + Text)
    
    // --- State ---
    reg [3:0] list_items [0:MAX_ITEMS-1]; // Item ID at each slot (0-8)
    reg [7:0] list_counts [0:MAX_ITEMS-1]; // Count at each slot
    reg [3:0] active_rows;                // How many rows are currently used
    
    // --- Helper: Find Item in List ---
    integer i;
    reg [3:0] found_slot;
    reg found;
    
    always @(*) begin
        found = 0;
        found_slot = active_rows; // Default: Next new slot
        
        for (i = 0; i < MAX_ITEMS; i = i + 1) begin
            if (i < active_rows) begin
                if (list_items[i] == item_index) begin
                    found = 1;
                    found_slot = i;
                end
            end
        end
    end
    
    // --- Output Target Y for Animation ---
    always @(*) begin
        // Slot 0 is at BOTTOM_Y. Slot 1 is at BOTTOM_Y - 60.
        // Target is the top-left Y of the icon slot.
        target_y_pos = BOTTOM_Y - (found_slot * ROW_HEIGHT);
    end

    // --- Update Logic ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            active_rows <= 0;
            for (i = 0; i < MAX_ITEMS; i = i + 1) begin
                list_items[i] <= 0;
                list_counts[i] <= 0;
            end
        end else if (clear_list) begin
            active_rows <= 0;
            for (i = 0; i < MAX_ITEMS; i = i + 1) begin
                list_items[i] <= 0;
                list_counts[i] <= 0;
            end
        end else if (update_trigger) begin
            if (found) begin
                list_counts[found_slot] <= list_counts[found_slot] + 1;
            end else if (active_rows < MAX_ITEMS) begin
                list_items[active_rows] <= item_index;
                list_counts[active_rows] <= 1;
                active_rows <= active_rows + 1;
            end
        end
    end

    // --- Rendering AGU (Address Generation Unit) ---
    // Determine which row we are rendering
    wire [10:0] rel_y_from_bottom = (BOTTOM_Y + ICON_HEIGHT) - pixel_y; // Offset from bottom of list stack
    reg [3:0] row_idx;
    
    // Check bounds
    // Y must be <= BOTTOM_Y + ICON_HEIGHT (approx 470) and >= Top of list
    wire in_v_range = (pixel_y <= BOTTOM_Y + ICON_HEIGHT) && (pixel_y > (BOTTOM_Y - (active_rows * ROW_HEIGHT)));
    
    // Optimization: Avoid division by 60
    // Use chained comparisons since active_rows is small (max 6)
    // BOTTOM_Y + ICON_HEIGHT - 1 = 400 + 60 - 1 = 459
    // pixel_y is subtracted from 459.
    // Range 0..59 -> Row 0
    // Range 60..119 -> Row 1
    // Range 120..179 -> Row 2
    wire [10:0] y_diff = (BOTTOM_Y + ICON_HEIGHT - 1) - pixel_y;
    always @(*) begin
        if (y_diff < 60) row_idx = 0;
        else if (y_diff < 120) row_idx = 1;
        else if (y_diff < 180) row_idx = 2;
        else if (y_diff < 240) row_idx = 3;
        else if (y_diff < 300) row_idx = 4;
        else if (y_diff < 360) row_idx = 5;
        else row_idx = 6; // Out of range
    end
    
    wire [9:0] row_top_y = BOTTOM_Y - (row_idx * ROW_HEIGHT);
    wire [9:0] rel_y_in_row = pixel_y - row_top_y; // 0..59
    wire [9:0] rel_x_in_list = pixel_x - START_X;
    
    // Zones
    wire in_icon_zone = (rel_x_in_list < ICON_WIDTH);
    wire in_text_zone = (rel_x_in_list >= TEXT_OFFSET_X) && (rel_x_in_list < TEXT_OFFSET_X + 60); // 60px for text
    
    // Valid Row means we are inside the vertical stack of items AND horizontal bounds
    wire valid_row = (row_idx < active_rows) && in_v_range && (pixel_x >= START_X) && (pixel_x < START_X + LIST_WIDTH);

    // AGU for Icon (Sprite 10x10 scaled 6x)
    // Optimization: x / 6 ~= (x * 43) >> 8
    wire [15:0] unscaled_x_mult = rel_x_in_list * 43;
    wire [15:0] unscaled_y_mult = rel_y_in_row * 43;
    wire [3:0] unscaled_x = unscaled_x_mult[11:8];
    wire [3:0] unscaled_y = unscaled_y_mult[11:8];
    
    always @(*) begin
        if (valid_row && in_icon_zone) begin
            is_reading_ram = 1;
            item_id_out = list_items[row_idx];
            // Address = (Frame5 * 10 + Y) * 10 + X
            // Use Frame 5 (last one) which is the bottle itself
            ram_addr = (50 + unscaled_y) * 10 + unscaled_x;
        end else begin
            is_reading_ram = 0;
            item_id_out = 0;
            ram_addr = 0;
        end
    end

    // --- Text Rendering ---
    reg [6:0] char_code;
    wire [2:0] char_col = (pixel_x - (START_X + TEXT_OFFSET_X)) & 7;
    // Move text down: was 22, now 38 (+16)
    wire [3:0] char_row = (pixel_y - row_top_y - 38); 
    wire [3:0] char_pos = (pixel_x - (START_X + TEXT_OFFSET_X)) >> 3;
    
    reg [7:0] render_count;
    
    always @(*) begin
        // Move text down range: was 22..38, now 38..54
        if (valid_row && in_text_zone && (pixel_y >= row_top_y + 38) && (pixel_y < row_top_y + 54)) begin
            render_count = list_counts[row_idx];
            case (char_pos)
                0: char_code = "x";
                1: char_code = " ";
                2: char_code = (render_count >= 10) ? ("0" + render_count/10) : ("0" + render_count%10);
                3: char_code = (render_count >= 10) ? ("0" + render_count%10) : 0;
                default: char_code = 0;
            endcase
        end else begin
            char_code = 0;
        end
    end

    wire font_bit;
    pc_vga_8x16_00_7F font_rom (
        .clk(clk),
        .ascii_code(char_code),
        .row(char_row),
        .col(char_col),
        .row_of_pixels(font_bit)
    );

    // --- Final Output ---
    always @(*) begin
        is_drawing = 0;
        rgb_out = 12'h000;
        
        if (valid_row) begin
            // Default: Black background
            is_drawing = 1;
            rgb_out = 12'h000; 
            
            if (in_icon_zone && is_reading_ram) begin
                // Draw Icon
                if (sram_data != TRANSPARENT_COLOR) begin // Simple transparency check
                    rgb_out = sram_data;
                end
            end else if (in_text_zone && char_code != 0 && font_bit) begin
                // Draw Text
                rgb_out = 12'hFFF;
            end
        end
    end

endmodule