// bin2bcd.v
// Module: Binary to BCD Converter (Iterative)
// Description: Converts 16-bit binary to 4-digit BCD using Double Dabble algorithm
//              Iterative implementation to improve timing (WNS).
//              Updates output only when conversion is complete.
//
// Algorithm: Shift-and-Add-3 (Double Dabble)
// Latency: ~17 clock cycles per update.

module bin2bcd (
    input wire clk,
    input wire reset,
    input wire [15:0] binary,       // Binary input (0-65535)
    output reg [3:0] bcd_ones,      // Ones digit (0-9)
    output reg [3:0] bcd_tens,      // Tens digit (0-9)
    output reg [3:0] bcd_hundreds,  // Hundreds digit (0-9)
    output reg [3:0] bcd_thousands  // Thousands digit (0-9)
);

// State definitions
localparam IDLE    = 2'd0;
localparam CONVERT = 2'd1;
localparam UPDATE  = 2'd2;

reg [1:0] state;
reg [15:0] old_binary;          // To detect input changes
reg [31:0] shift_reg;           // [BCD | Binary]
reg [4:0]  loop_count;          // Iterator (0-15)

// Combinational logic for the "Add 3" step
reg [31:0] shift_reg_next;

always @(*) begin
    shift_reg_next = shift_reg;
    if (shift_reg_next[19:16] >= 5) shift_reg_next[19:16] = shift_reg_next[19:16] + 3;
    if (shift_reg_next[23:20] >= 5) shift_reg_next[23:20] = shift_reg_next[23:20] + 3;
    if (shift_reg_next[27:24] >= 5) shift_reg_next[27:24] = shift_reg_next[27:24] + 3;
    if (shift_reg_next[31:28] >= 5) shift_reg_next[31:28] = shift_reg_next[31:28] + 3;
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        bcd_ones <= 4'd0;
        bcd_tens <= 4'd0;
        bcd_hundreds <= 4'd0;
        bcd_thousands <= 4'd0;
        old_binary <= 16'd0;
        loop_count <= 5'd0;
        shift_reg <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                // Constantly check if input changed
                if (binary != old_binary) begin
                    old_binary <= binary;
                    shift_reg <= {16'd0, binary}; // Load new value
                    loop_count <= 5'd0;
                    state <= CONVERT;
                end
            end

            CONVERT: begin
                // Double Dabble Algorithm: Shift and Add 3
                if (loop_count < 16) begin
                    // Shift left the result of the "Add 3" combinational logic
                    shift_reg <= shift_reg_next << 1;
                    loop_count <= loop_count + 1;
                end else begin
                    // Done 16 iterations
                    state <= UPDATE;
                end
            end

            UPDATE: begin
                // Update outputs
                bcd_ones      <= shift_reg[19:16];
                bcd_tens      <= shift_reg[23:20];
                bcd_hundreds  <= shift_reg[27:24];
                bcd_thousands <= shift_reg[31:28];
                state <= IDLE; // Ready for next change
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule
