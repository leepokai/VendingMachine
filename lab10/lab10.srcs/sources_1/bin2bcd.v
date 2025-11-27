// bin2bcd.v
// Module: Binary to BCD Converter
// Description: Converts 16-bit binary to 4-digit BCD using Double Dabble algorithm
// Algorithm: Shift-and-Add-3 (Double Dabble)
//
// Input: 16-bit binary (0-65535)
// Output: 4 BCD digits (0-9999)
//
// Double Dabble Algorithm:
// 1. Initialize shift register: [BCD_thousands BCD_hundreds BCD_tens BCD_ones | Binary]
// 2. Repeat 16 times (for each bit):
//    a. For each BCD digit, if >= 5, add 3
//    b. Left shift entire register by 1
// 3. Extract BCD digits from register

module bin2bcd (
    input wire clk,
    input wire reset,
    input wire [15:0] binary,       // Binary input (0-65535)
    output reg [3:0] bcd_ones,      // Ones digit (0-9)
    output reg [3:0] bcd_tens,      // Tens digit (0-9)
    output reg [3:0] bcd_hundreds,  // Hundreds digit (0-9)
    output reg [3:0] bcd_thousands  // Thousands digit (0-9)
);

// Shift register: [thousands | hundreds | tens | ones | binary]
// Total: 4 + 4 + 4 + 4 + 16 = 32 bits
reg [31:0] shift_reg;
integer i;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        bcd_ones <= 4'd0;
        bcd_tens <= 4'd0;
        bcd_hundreds <= 4'd0;
        bcd_thousands <= 4'd0;
    end else begin
        // Initialize shift register: BCD parts = 0, binary part = input
        shift_reg = {16'd0, binary};

        // Perform 16 iterations (one for each bit)
        for (i = 0; i < 16; i = i + 1) begin
            // Add 3 to BCD digits >= 5 (before shift)
            if (shift_reg[19:16] >= 5)  // Ones digit
                shift_reg[19:16] = shift_reg[19:16] + 3;
            if (shift_reg[23:20] >= 5)  // Tens digit
                shift_reg[23:20] = shift_reg[23:20] + 3;
            if (shift_reg[27:24] >= 5)  // Hundreds digit
                shift_reg[27:24] = shift_reg[27:24] + 3;
            if (shift_reg[31:28] >= 5)  // Thousands digit
                shift_reg[31:28] = shift_reg[31:28] + 3;

            // Left shift by 1
            shift_reg = shift_reg << 1;
        end

        // Extract BCD digits (after all shifts, they're in upper 16 bits)
        bcd_ones      <= shift_reg[19:16];
        bcd_tens      <= shift_reg[23:20];
        bcd_hundreds  <= shift_reg[27:24];
        bcd_thousands <= shift_reg[31:28];
    end
end

endmodule
