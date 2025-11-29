// price_calculator.v
// Module: Price Calculator
// Description: Calculates total amount due based on cart quantities and drink prices
//
// Formula: total_due = Σ(drink_price[i] × cart_quantity[i]) for i = 0 to 8
// This module is pipelined to meet timing requirements.

module price_calculator (
    input wire clk,
    input wire reset,

    // Price inputs for 9 drinks (in dollar units, e.g., $10, $15)
    input wire [7:0] price_0,
    input wire [7:0] price_1,
    input wire [7:0] price_2,
    input wire [7:0] price_3,
    input wire [7:0] price_4,
    input wire [7:0] price_5,
    input wire [7:0] price_6,
    input wire [7:0] price_7,
    input wire [7:0] price_8,

    // Cart quantity inputs for 9 drinks (0-5 per drink)
    input wire [2:0] qty_0,
    input wire [2:0] qty_1,
    input wire [2:0] qty_2,
    input wire [2:0] qty_3,
    input wire [2:0] qty_4,
    input wire [2:0] qty_5,
    input wire [2:0] qty_6,
    input wire [2:0] qty_7,
    input wire [2:0] qty_8,

    // Total amount due output (max: 9 drinks × 5 qty × 255 price = 11475, needs 14 bits)
    output reg [15:0] total_due
);

// Pipeline Stage 1: Registered multiplication results
// price[7:0] * qty[2:0] -> product[10:0]
reg [10:0] product_regs [0:8];

// Pipeline Stage 2: Sum of products
// This stage sums the registered products.
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // Reset both pipeline stages
        product_regs[0] <= 11'd0;
        product_regs[1] <= 11'd0;
        product_regs[2] <= 11'd0;
        product_regs[3] <= 11'd0;
        product_regs[4] <= 11'd0;
        product_regs[5] <= 11'd0;
        product_regs[6] <= 11'd0;
        product_regs[7] <= 11'd0;
        product_regs[8] <= 11'd0;
        total_due <= 16'd0;
    end else begin
        // --- Pipeline Stage 1: Multiplication ---
        // Calculate and register individual products (price × quantity)
        product_regs[0] <= price_0 * qty_0;
        product_regs[1] <= price_1 * qty_1;
        product_regs[2] <= price_2 * qty_2;
        product_regs[3] <= price_3 * qty_3;
        product_regs[4] <= price_4 * qty_4;
        product_regs[5] <= price_5 * qty_5;
        product_regs[6] <= price_6 * qty_6;
        product_regs[7] <= price_7 * qty_7;
        product_regs[8] <= price_8 * qty_8;

        // --- Pipeline Stage 2: Summation ---
        // Sum all registered products to get the final total_due
        total_due <= product_regs[0] + product_regs[1] + product_regs[2] +
                     product_regs[3] + product_regs[4] + product_regs[5] +
                     product_regs[6] + product_regs[7] + product_regs[8];
    end
end

endmodule
