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

    // --- Rendering AGU & Pipeline ---
    // We use a 4-stage pipeline to break critical paths and align with SRAM latency (2 cycles in Top).
    
    // Intermediate Wires (Combinational)
    wire [10:0] y_diff = (BOTTOM_Y + ICON_HEIGHT - 1) - pixel_y;
    wire [9:0] rel_x_in_list = pixel_x - START_X;
    wire in_v_range = (pixel_y <= BOTTOM_Y + ICON_HEIGHT) && (pixel_y > (BOTTOM_Y - (active_rows * ROW_HEIGHT)));
    
    // Helper to determine row index combinationally for the first pipeline stage
    reg [3:0] comb_row_idx;
    always @(*) begin
        if (y_diff < 60) comb_row_idx = 0;
        else if (y_diff < 120) comb_row_idx = 1;
        else if (y_diff < 180) comb_row_idx = 2;
        else if (y_diff < 240) comb_row_idx = 3;
        else if (y_diff < 300) comb_row_idx = 4;
        else if (y_diff < 360) comb_row_idx = 5;
        else comb_row_idx = 6;
    end

    // --- Pipeline Registers ---
    // Stage 1
    reg [9:0] p1_rel_x;
    reg [3:0] p1_row_idx;
    reg p1_valid_row, p1_in_icon_zone, p1_in_text_zone;
    reg p1_text_row_valid; // New: Explicit valid flag for text vertical range
    reg [3:0] p1_item_id;
    reg [7:0] p1_count;
    reg [3:0] p1_unscaled_x, p1_unscaled_y;
    reg [3:0] p1_char_row_offset;
    
    // Stage 2
    reg [3:0] p2_item_id;
    reg p2_in_icon_zone, p2_in_text_zone, p2_valid_row;
    reg [6:0] p2_char_code;
    reg [3:0] p2_char_row;
    reg [2:0] p2_char_col;
    
    // Stage 3
    reg [3:0] p3_item_id;
    reg p3_in_icon_zone, p3_in_text_zone, p3_valid_row;
    reg [6:0] p3_char_code;
    reg [3:0] p3_char_row;
    reg [2:0] p3_char_col;

    // Stage 1 Logic (Coordinate & Lookup)
    // Helper wire for modulo 60 calculation (Timing optimized: avoid % operator)
    // We already know comb_row_idx. y_diff % 60 == y_diff - (comb_row_idx * 60)
    // 60 * x = (x << 6) - (x << 2) = x*64 - x*4
    wire [10:0] row_offset_base = (comb_row_idx << 6) - (comb_row_idx << 2);
    wire [5:0] rel_y_mod_60 = y_diff - row_offset_base; 
    wire [5:0] rel_y_in_slot = 59 - rel_y_mod_60; // 0 (top) to 59 (bottom) of the slot

    always @(posedge clk) begin
        if (reset) begin
            p1_rel_x <= 0; p1_row_idx <= 0;
            p1_valid_row <= 0; p1_in_icon_zone <= 0; p1_in_text_zone <= 0;
            p1_text_row_valid <= 0;
            p1_item_id <= 0; p1_count <= 0;
            p1_unscaled_x <= 0; p1_unscaled_y <= 0;
            p1_char_row_offset <= 0;
        end else begin
            // 1. Calculate Row Index 
            p1_row_idx <= comb_row_idx;

            // 2. Coordinates
            p1_rel_x <= rel_x_in_list;
            
            // Use calculated rel_y_in_slot for scaling (0..59)
            p1_unscaled_y <= (rel_y_in_slot * 43) >> 8;
            p1_unscaled_x <= (rel_x_in_list * 43) >> 8;
            
            // Text Vertical Range Check: 38 to 53 (Height 16)
            if (rel_y_in_slot >= 38 && rel_y_in_slot < 54) begin
                p1_text_row_valid <= 1;
                p1_char_row_offset <= rel_y_in_slot - 38;
            end else begin
                p1_text_row_valid <= 0;
                p1_char_row_offset <= 0; // Don't care
            end

            // 3. Flags
            p1_valid_row <= (comb_row_idx < active_rows) && in_v_range && (pixel_x >= START_X) && (pixel_x < START_X + LIST_WIDTH);
            p1_in_icon_zone <= (rel_x_in_list < ICON_WIDTH);
            p1_in_text_zone <= (rel_x_in_list >= TEXT_OFFSET_X) && (rel_x_in_list < TEXT_OFFSET_X + 60);
            
            // 4. Data Lookup
            p1_item_id <= list_items[comb_row_idx];
            p1_count <= list_counts[comb_row_idx];
        end
    end

    // Stage 2 Logic (Address Gen & Char Code)
    always @(posedge clk) begin
        if (reset) begin
            ram_addr <= 0; is_reading_ram <= 0;
            p2_item_id <= 0; p2_valid_row <= 0;
            p2_in_icon_zone <= 0; p2_in_text_zone <= 0;
            p2_char_code <= 0; p2_char_row <= 0; p2_char_col <= 0;
        end else begin
            // 1. Address Generation (Output to Top)
            if (p1_valid_row && p1_in_icon_zone) begin
                is_reading_ram <= 1;
                ram_addr <= (50 + p1_unscaled_y) * 10 + p1_unscaled_x;
            end else begin
                is_reading_ram <= 0;
                ram_addr <= 0;
            end
            
            // 2. Text Logic (Generate Char Code)
            // Use the explicit valid flag instead of checking offset range
            if (p1_valid_row && p1_in_text_zone && p1_text_row_valid) begin
                case ((p1_rel_x - TEXT_OFFSET_X) >> 3) // char_pos
                    0: p2_char_code <= "x";
                    1: p2_char_code <= " ";
                    2: p2_char_code <= (p1_count >= 10) ? ("0" + p1_count/10) : ("0" + p1_count%10);
                    3: p2_char_code <= (p1_count >= 10) ? ("0" + p1_count%10) : 0;
                    default: p2_char_code <= 0;
                endcase
            end else begin
                p2_char_code <= 0;
            end
            p2_char_row <= p1_char_row_offset;
            p2_char_col <= (p1_rel_x - TEXT_OFFSET_X) & 7;

            // 3. Pass-through
            p2_item_id <= p1_item_id;
            p2_valid_row <= p1_valid_row;
            p2_in_icon_zone <= p1_in_icon_zone;
            p2_in_text_zone <= p1_in_text_zone;
        end
    end

    // Stage 3 (Delay Line - Waiting for SRAM Address Latch in Top)
    always @(posedge clk) begin
        if (reset) begin
            p3_item_id <= 0; p3_valid_row <= 0;
            p3_in_icon_zone <= 0; p3_in_text_zone <= 0;
            p3_char_code <= 0; p3_char_row <= 0; p3_char_col <= 0;
        end else begin
            p3_item_id <= p2_item_id;
            p3_valid_row <= p2_valid_row;
            p3_in_icon_zone <= p2_in_icon_zone;
            p3_in_text_zone <= p2_in_text_zone;
            p3_char_code <= p2_char_code;
            p3_char_row <= p2_char_row;
            p3_char_col <= p2_char_col;
        end
    end

    // Stage 4 (Final Output - Align with SRAM Data)
    wire font_bit;
    // Instantiate Font ROM (Sync Read takes 1 cycle, so inputs at Stage 3, output valid at Stage 4)
    pc_vga_8x16_00_7F font_rom (
        .clk(clk),
        .ascii_code(p3_char_code), // Input from Stage 3
        .row(p3_char_row),
        .col(p3_char_col),
        .row_of_pixels(font_bit)   // Output valid at Stage 4
    );

    always @(posedge clk) begin
        if (reset) begin
            rgb_out <= 0; is_drawing <= 0; item_id_out <= 0;
        end else begin
            // 1. Output Item ID for MUX (This selects the data we are about to use)
            // Wait. Lab10 MUX uses item_id_out combinationaly to feed sram_data.
            // If sram_data arrives at S4, we need item_id_out to be valid at S4?
            // Yes, because "sram_data" wire in this module is driven by "list_sram_data_mux".
            // "list_sram_data_mux" is driven by "list_item_id_out".
            // So to read correctly at S4, list_item_id_out must be p3_item_id (registered to S4).
            item_id_out <= p3_item_id; 

            // 2. Final Draw Logic
            is_drawing <= 0;
            rgb_out <= 12'h000;

            if (p3_valid_row) begin
                // Background
                is_drawing <= 1;
                rgb_out <= 12'h000;

                if (p3_in_icon_zone) begin
                    // Sram data is valid now (latched from Top MUX)
                    if (sram_data != TRANSPARENT_COLOR) begin
                        rgb_out <= sram_data;
                    end
                end else if (p3_in_text_zone && p3_char_code != 0 && font_bit) begin
                    rgb_out <= 12'hFFF;
                end
            end
        end
    end

endmodule