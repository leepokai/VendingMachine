// price_calculator.v
// Module: Price Calculator
// Description: Calculates total amount due based on cart quantities and drink prices
//
// Formula: total_due = Σ(drink_price[i] × cart_quantity[i]) for i = 0 to 8

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

// Intermediate multiplication results
wire [10:0] product_0, product_1, product_2;
wire [10:0] product_3, product_4, product_5;
wire [10:0] product_6, product_7, product_8;

// Calculate individual products (price × quantity)
assign product_0 = price_0 * qty_0;
assign product_1 = price_1 * qty_1;
assign product_2 = price_2 * qty_2;
assign product_3 = price_3 * qty_3;
assign product_4 = price_4 * qty_4;
assign product_5 = price_5 * qty_5;
assign product_6 = price_6 * qty_6;
assign product_7 = price_7 * qty_7;
assign product_8 = price_8 * qty_8;

// Registered sum for timing closure
always @(posedge clk or posedge reset) begin
    if (reset) begin
        total_due <= 16'd0;
    end else begin
        // Sum all products to get total amount due
        total_due <= product_0 + product_1 + product_2 +
                     product_3 + product_4 + product_5 +
                     product_6 + product_7 + product_8;
    end
end

endmodule
