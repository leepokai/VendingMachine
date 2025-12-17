// coin_selector.v
// Module: Coin Selector FSM
// Description: Manages coin selection with vertical navigation (3 coins)
//
// Coin Types:
// 0: $1 coin
// 1: $5 coin
// 2: $10 coin

module coin_selector (
    input wire clk,
    input wire reset,
    input wire btn_up,      // btn0 - move selection up
    input wire btn_down,    // btn1 - move selection down
    output reg [1:0] coin_index  // 0, 1, or 2
);

// Edge detection for buttons
reg btn_up_d, btn_down_d;
wire btn_up_posedge, btn_down_posedge;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        btn_up_d <= 1'b0;
        btn_down_d <= 1'b0;
    end else begin
        btn_up_d <= btn_up;
        btn_down_d <= btn_down;
    end
end

assign btn_up_posedge = btn_up && ~btn_up_d;
assign btn_down_posedge = btn_down && ~btn_down_d;

// Coin selection logic (vertical navigation)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        coin_index <= 2'd0;  // Start with $1 coin
    end else begin
        if (btn_down_posedge) begin
            if (coin_index == 2'd3)
                coin_index <= 2'd0;  // Wrap to top
            else
                coin_index <= coin_index + 1;
        end else if (btn_up_posedge) begin
            if (coin_index == 2'd0)
                coin_index <= 2'd3;  // Wrap to bottom
            else
                coin_index <= coin_index - 1;
        end
    end
end

endmodule
