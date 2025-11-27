// main_fsm.v
// Module: Main State Machine
// Description: Controls main vending machine states (SELECTION -> PAYMENT)
//
// States:
// - SELECTION (0): User selects drinks and quantities
// - PAYMENT (1): User selects coins to pay

module main_fsm (
    input wire clk,
    input wire reset,
    input wire btn_confirm,     // btn3 - transition to next state
    input wire dispensing,      // Currently dispensing change
    input wire dispense_done,   // Dispensing completed
    output reg current_state    // 0=SELECTION, 1=PAYMENT
);

// State definitions
localparam STATE_SELECTION = 1'b0;
localparam STATE_PAYMENT   = 1'b1;

// Edge detection for confirm button
reg btn_confirm_d;
wire btn_confirm_posedge;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        btn_confirm_d <= 1'b0;
    end else begin
        btn_confirm_d <= btn_confirm;
    end
end

assign btn_confirm_posedge = btn_confirm && ~btn_confirm_d;

// State machine
always @(posedge clk or posedge reset) begin
    if (reset) begin
        current_state <= STATE_SELECTION;
    end else begin
        case (current_state)
            STATE_SELECTION: begin
                if (btn_confirm_posedge)
                    current_state <= STATE_PAYMENT;
            end
            STATE_PAYMENT: begin
                // Return to SELECTION if:
                // - btn3 pressed AND not currently dispensing AND dispensing has completed
                if (btn_confirm_posedge && !dispensing && dispense_done)
                    current_state <= STATE_SELECTION;
                else
                    current_state <= STATE_PAYMENT;
            end
            default: begin
                current_state <= STATE_SELECTION;
            end
        endcase
    end
end

endmodule
