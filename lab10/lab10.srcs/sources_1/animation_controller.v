`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: animation_controller
// Description: Manages the sequential playback of animations for multiple purchased items.
//              Iterates through the cart quantity array and plays the drop animation
//              for each item count.
//////////////////////////////////////////////////////////////////////////////////

module animation_controller (
    input wire clk,
    input wire reset,
    input wire start,                 // Trigger to start the sequence (pulse)
    input wire [26:0] flat_cart_quantity, // Flattened cart: 9 items * 3 bits
    input wire [9:0] target_y_pos,    // Destination Y coordinate for the flying item
    
    output reg animation_active,      // High when dropping animation is playing
    output reg flying_active,         // High when flying animation is playing
    output reg [2:0] frame_index,     // Current frame (0-5)
    output reg [3:0] current_item_index, // The item currently being animated
    output reg [9:0] anim_x,          // Current X position of the sprite
    output reg [9:0] anim_y,          // Current Y position of the sprite
    output reg list_update_trigger,   // Pulse when flight completes
    output reg sequence_done          // Pulse when ALL animations in the cart are finished
);

    // Latch the cart quantity when start is triggered
    reg [26:0] latched_cart_flat;
    
    // Unpack cart quantity from the LATCHED register, not the direct input
    wire [2:0] cart [0:8];
    assign cart[0] = latched_cart_flat[2:0];
    assign cart[1] = latched_cart_flat[5:3];
    assign cart[2] = latched_cart_flat[8:6];
    assign cart[3] = latched_cart_flat[11:9];
    assign cart[4] = latched_cart_flat[14:12];
    assign cart[5] = latched_cart_flat[17:15];
    assign cart[6] = latched_cart_flat[20:18];
    assign cart[7] = latched_cart_flat[23:21];
    assign cart[8] = latched_cart_flat[26:24];

    // FSM States
    localparam IDLE = 0;
    localparam CHECK_NEXT_ITEM = 1;
    localparam START_ANIM = 2;
    localparam ANIMATING = 3;
    localparam START_FLY = 4;
    localparam FLYING = 5;
    
    reg [2:0] state;
    reg [3:0] item_ptr;             // Pointer to current item type (0-8)
    reg [2:0] items_played_count;   // How many of the current item type have been played

    // Timer for frames (100MHz / 10 FPS = 10,000,000 cycles)
    localparam FRAME_DURATION = 27'd10000000;
    reg [26:0] frame_timer;

    // Animation Constants
    // TODO: These should ideally be parameters or inputs to match lab10.v exactly
    localparam START_X = 290; // (640 - 60) / 2
    localparam START_Y = 325; // Approximate drop zone Y
    localparam END_X = 530;   // Target list X position (matches cart_list_renderer START_X)

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            animation_active <= 0;
            flying_active <= 0;
            frame_index <= 0;
            current_item_index <= 0;
            item_ptr <= 0;
            items_played_count <= 0;
            frame_timer <= 0;
            latched_cart_flat <= 0;
            anim_x <= START_X;
            anim_y <= START_Y;
            list_update_trigger <= 0;
            sequence_done <= 0;
        end else begin
            // Default pulse reset
            list_update_trigger <= 0;
            sequence_done <= 0;

            case (state)
                IDLE: begin
                    animation_active <= 0;
                    flying_active <= 0;
                    if (start) begin
                        // Latch the input data immediately!
                        latched_cart_flat <= flat_cart_quantity;
                        
                        state <= CHECK_NEXT_ITEM;
                        item_ptr <= 0;
                        items_played_count <= 0;
                    end
                end

                CHECK_NEXT_ITEM: begin
                    if (item_ptr > 8) begin
                        // All items processed
                        state <= IDLE;
                        animation_active <= 0;
                        sequence_done <= 1; // Pulse done signal
                    end else if (cart[item_ptr] > items_played_count) begin
                        // Found an item to animate
                        current_item_index <= item_ptr;
                        state <= START_ANIM;
                    end else begin
                        // Done with this item type, check next
                        item_ptr <= item_ptr + 1;
                        items_played_count <= 0;
                    end
                end

                START_ANIM: begin
                    // Initialize animation for one unit
                    animation_active <= 1;
                    flying_active <= 0;
                    frame_index <= 0;
                    frame_timer <= 0;
                    anim_x <= START_X; // Reset position
                    anim_y <= START_Y;
                    state <= ANIMATING;
                end

                ANIMATING: begin
                    if (frame_timer >= FRAME_DURATION - 1) begin
                        frame_timer <= 0;
                        if (frame_index < 5) begin
                            frame_index <= frame_index + 1;
                        end else begin
                            // Drop animation done, start flying
                            state <= START_FLY;
                        end
                    end else begin
                        frame_timer <= frame_timer + 1;
                    end
                end

                START_FLY: begin
                    flying_active <= 1;
                    // frame_index stays at 5 (last frame)
                    state <= FLYING;
                end

                FLYING: begin
                    // Simple movement logic: Move 2 pixels per clock tick (or slower)
                    // Let's slow it down: Move every N cycles
                    if (frame_timer >= 27'd500_000) begin // Speed control
                        frame_timer <= 0;
                        
                        // Move X
                        if (anim_x < END_X)
                            anim_x <= anim_x + 4; // Move right
                            
                        // Move Y
                        // Simple linear interpolation approach:
                        // If we are far from X target, move Y slowly.
                        // Or just move Y towards target_y_pos
                        if (anim_y < target_y_pos)
                            anim_y <= anim_y + 2;
                        else if (anim_y > target_y_pos)
                            anim_y <= anim_y - 2;
                            
                        // Check arrival
                        if (anim_x >= END_X) begin
                            list_update_trigger <= 1; // Pulse update
                            items_played_count <= items_played_count + 1;
                            flying_active <= 0; // Hide sprite
                            state <= CHECK_NEXT_ITEM;
                        end
                    end else begin
                        frame_timer <= frame_timer + 1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
