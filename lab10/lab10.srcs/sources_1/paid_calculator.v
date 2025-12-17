// paid_calculator.v
// Module: Paid Amount Calculator
// Description: Calculates total amount paid based on inserted coins
//
// Formula: paid_amount = coin1_count × $1 + coin5_count × $5 + coin10_count × $10

module paid_calculator (
    input wire clk,
    input wire reset,

    // Coin counts
    input wire [7:0] coin1_count,   // Number of $1 coins inserted
    input wire [7:0] coin5_count,   // Number of $5 coins inserted
    input wire [7:0] coin10_count,  // Number of $10 coins inserted
    input wire [7:0] coin100_count, // Number of $100 bills inserted

    // Total amount paid output (max: 255×1 + 255×5 + 255×10 + 255*100 = huge, needs 16 bits is fine up to 65535)
    output reg [15:0] paid_amount
);

// Intermediate multiplication results
wire [15:0] amount_1, amount_5, amount_10, amount_100;

// Calculate individual amounts (coin_count × denomination)
assign amount_1  = coin1_count;          // $1 × count
assign amount_5  = coin5_count * 5;      // $5 × count
assign amount_10 = coin10_count * 10;    // $10 × count
assign amount_100 = coin100_count * 100; // $100 × count

// Registered sum for timing closure
always @(posedge clk or posedge reset) begin
    if (reset) begin
        paid_amount <= 16'd0;
    end else begin
        // Sum all amounts to get total paid
        paid_amount <= amount_1 + amount_5 + amount_10 + amount_100;
    end
end

endmodule
