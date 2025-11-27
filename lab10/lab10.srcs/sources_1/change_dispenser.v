// change_dispenser.v
// Module: Change Dispenser
// Description: Calculates coin dispensing using greedy algorithm
// Algorithm: Iteratively dispense largest coins first ($10 -> $5 -> $1)

module change_dispenser (
    input wire clk,
    input wire reset,
    input wire start,                    // Trigger to start dispensing
    input wire [15:0] change_amount,     // Amount to dispense
    input wire [7:0] avail_coin1,        // Available $1 coins
    input wire [7:0] avail_coin5,        // Available $5 coins
    input wire [7:0] avail_coin10,       // Available $10 coins
    output reg [7:0] dispense_coin1,     // $1 coins to dispense
    output reg [7:0] dispense_coin5,     // $5 coins to dispense
    output reg [7:0] dispense_coin10,    // $10 coins to dispense
    output reg done,                     // Calculation complete
    output reg success                   // 1 if exact change possible
);

// State machine states
localparam IDLE     = 3'd0;
localparam CALC_10  = 3'd1;
localparam CALC_5   = 3'd2;
localparam CALC_1   = 3'd3;
localparam DONE     = 3'd4;

reg [2:0] state, next_state;
reg [15:0] remaining;           // Remaining amount to dispense
reg [7:0] count_10, count_5, count_1;  // Counters for each denomination

// State register
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = CALC_10;
            else
                next_state = IDLE;
        end

        CALC_10: begin
            // Check if we can dispense more $10 coins
            if (remaining >= 16'd10 && count_10 < avail_coin10)
                next_state = CALC_10;  // Stay in this state
            else
                next_state = CALC_5;   // Move to $5
        end

        CALC_5: begin
            // Check if we can dispense more $5 coins
            if (remaining >= 16'd5 && count_5 < avail_coin5)
                next_state = CALC_5;   // Stay in this state
            else
                next_state = CALC_1;   // Move to $1
        end

        CALC_1: begin
            // Check if we can dispense more $1 coins
            if (remaining >= 16'd1 && count_1 < avail_coin1)
                next_state = CALC_1;   // Stay in this state
            else
                next_state = DONE;     // Finished
        end

        DONE: begin
            next_state = IDLE;         // Return to idle
        end

        default: next_state = IDLE;
    endcase
end

// Output and datapath logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        remaining <= 16'd0;
        count_10 <= 8'd0;
        count_5 <= 8'd0;
        count_1 <= 8'd0;
        dispense_coin1 <= 8'd0;
        dispense_coin5 <= 8'd0;
        dispense_coin10 <= 8'd0;
        done <= 1'b0;
        success <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize for new calculation
                    remaining <= change_amount;
                    count_10 <= 8'd0;
                    count_5 <= 8'd0;
                    count_1 <= 8'd0;
                    done <= 1'b0;
                    success <= 1'b0;
                end else begin
                    // Clear outputs when idle (not calculating)
                    dispense_coin1 <= 8'd0;
                    dispense_coin5 <= 8'd0;
                    dispense_coin10 <= 8'd0;
                    done <= 1'b0;
                    success <= 1'b0;
                end
            end

            CALC_10: begin
                // Dispense one $10 coin if possible
                if (remaining >= 16'd10 && count_10 < avail_coin10) begin
                    remaining <= remaining - 16'd10;
                    count_10 <= count_10 + 8'd1;
                end
            end

            CALC_5: begin
                // Dispense one $5 coin if possible
                if (remaining >= 16'd5 && count_5 < avail_coin5) begin
                    remaining <= remaining - 16'd5;
                    count_5 <= count_5 + 8'd1;
                end
            end

            CALC_1: begin
                // Dispense one $1 coin if possible
                if (remaining >= 16'd1 && count_1 < avail_coin1) begin
                    remaining <= remaining - 16'd1;
                    count_1 <= count_1 + 8'd1;
                end
            end

            DONE: begin
                // Update outputs
                dispense_coin10 <= count_10;
                dispense_coin5 <= count_5;
                dispense_coin1 <= count_1;
                done <= 1'b1;

                // Check if exact change was made
                if (remaining == 16'd0)
                    success <= 1'b1;
                else
                    success <= 1'b0;
            end
        endcase
    end
end

endmodule
