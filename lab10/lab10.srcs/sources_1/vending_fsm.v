// vending_fsm.v
module vending_fsm (
    input wire clk,
    input wire reset,
    input wire btn_left,
    input wire btn_right,
    output reg [3:0] selection_index // 4 bits for 0-8
);

// Edge detection to register a single press
reg btn_left_d, btn_right_d;
wire btn_left_posedge, btn_right_posedge;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        btn_left_d <= 0;
        btn_right_d <= 0;
    end else begin
        btn_left_d <= btn_left;
        btn_right_d <= btn_right;
    end
end

assign btn_left_posedge = btn_left && ~btn_left_d;
assign btn_right_posedge = btn_right && ~btn_right_d;

// Index update logic
always @(posedge clk or posedge reset) begin
    if (reset) begin
        selection_index <= 0;
    end else begin
        if (btn_right_posedge) begin
            if (selection_index == 8)
                selection_index <= 0; // Wrap around
            else
                selection_index <= selection_index + 1;
        end else if (btn_left_posedge) begin
            if (selection_index == 0)
                selection_index <= 8; // Wrap around
            else
                selection_index <= selection_index - 1;
        end
    end
end

endmodule
