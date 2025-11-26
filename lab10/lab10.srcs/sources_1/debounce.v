// lab10/lab10.srcs/sources_1/debounce.v
module debounce #(
    parameter DELAY_TIME = 20'd1_000_000 // 約 10ms for 100MHz clock (100MHz * 10ms = 1,000,000 cycles)
) (
    input wire clk,
    input wire reset,
    input wire btn_in,
    output wire btn_out
);

reg  [19:0] counter; // Adjust width based on DELAY_TIME
reg         btn_sync_0;
reg         btn_sync_1;
reg         btn_reg;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        btn_sync_0 <= 1'b0;
        btn_sync_1 <= 1'b0;
    end else begin
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        counter <= 0;
        btn_reg <= 1'b0;
    end else begin
        if (btn_sync_1 == btn_reg) begin
            counter <= 0; // Reset counter if input is stable
        end else begin
            if (counter < DELAY_TIME - 1) begin
                counter <= counter + 1; // Increment counter
            end else begin
                btn_reg <= btn_sync_1; // Input is stable for DELAY_TIME, update output
                counter <= 0; // Reset counter
            end
        end
    end
end

assign btn_out = btn_reg;

endmodule