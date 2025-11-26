//
// This module infers a block RAM. The memory content is initialized
// from the file path provided in the MEM_INIT_FILE parameter.
// If MEM_INIT_FILE is empty, the memory is uninitialized.
//

module sram
#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 16, RAM_SIZE = 65536, MEM_INIT_FILE = "")
 (input clk, input we, input en,
  input  [ADDR_WIDTH-1 : 0] addr,
  input  [DATA_WIDTH-1 : 0] data_i,
  output reg [DATA_WIDTH-1 : 0] data_o);

// Declare the memory cells
(* ram_style = "block" *) reg [DATA_WIDTH-1 : 0] RAM [RAM_SIZE - 1:0];

// Initialize the memory based on the file path parameter
initial begin
    if (MEM_INIT_FILE != "") begin
        $readmemh(MEM_INIT_FILE, RAM);
    end
end

// SRAM read operation
always@(posedge clk)
begin
  if (en) begin
    if (we)
      data_o <= data_i; // Write-through
    else
      data_o <= RAM[addr];
  end
end

// SRAM write operation
always@(posedge clk)
begin
  if (en & we)
    RAM[addr] <= data_i;
end

endmodule
