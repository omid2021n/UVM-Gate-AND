module dff (dff_if vif);

    always @(posedge vif.clk) begin
      if (vif.rst == 1'b1)
     
      vif.result <= 4'b0000;
    else
      vif.result <= vif.a & vif.b;
  end

endmodule

interface dff_if;
  logic clk;          // Clock signal
  logic rst;          // Reset signal
  logic [3:0] a;      // 4-bit input A
  logic [3:0] b;      // 4-bit input B
  logic [3:0] result; // 4-bit output 
endinterface
