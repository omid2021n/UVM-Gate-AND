class transaction;
  rand logic [3:0] a; // 4-bit random input A
  rand logic [3:0] b; // 4-bit random input B
  logic [3:0] result; // 4-bit result

  function transaction copy();
    copy = new();      // Create a new transaction object
    copy.a = this.a;   // Copy input A
    copy.b = this.b;   // Copy input B
    copy.result = this.result; // Copy output
  endfunction

  function void display(input string tag);
    $display("[%0s] : A : %4b B : %4b RESULT : %4b", tag, a, b, result); 
  endfunction
endclass

/////////////////////////////////         Generator 

class generator;
  transaction tr;  // Define a transaction object
  mailbox #(transaction) mbx;      // send data to the driver
  mailbox #(transaction) mbxref;   // send data to the scoreboard 
  
  event sconext; // Event to sense the completion of scoreboard work
  event done;    // Event to trigger when the requested number of stimuli is applied
  int count;     // Stimulus count

  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx;  // Initialize the mailbox for the driver
    this.mbxref = mbxref; // Initialize the mailbox for the scoreboard
    tr = new(); // Create a new transaction object
  endfunction
  //--------------------------run
  task run();
  repeat(count) begin
    assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
    tr.result = tr.a & tr.b; // Calculate expected result
    mbx.put(tr.copy); // Send transaction to driver
    mbxref.put(tr.copy); // Send transaction to scoreboard
    tr.display("GEN"); // Display transaction information
    @(sconext); // Wait for scoreboard completion
  end
  ->done; // Signal completion
endtask
endclass

/////////////////////////---------Driver 

class driver;
  transaction tr; 
  mailbox #(transaction) mbx; // mailbox to receive data from generator
  virtual dff_if vif; // Virtual interface for DUT

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx; // Initialize the mailbox for receiving data
  endfunction

  task reset();
    vif.rst <= 1'b1; // Assert reset signal
    vif.a <= 4'b0000; // Initialize input A to 0
    vif.b <= 4'b0000; // Initialize input B to 0
    repeat(5) @(posedge vif.clk); // Wait for 5 clock cycles
    vif.rst <= 1'b0; // Deassert reset signal
    @(posedge vif.clk); // Wait for one more clock cycle
    $display("[DRV] : RESET DONE"); // Display reset completion message
  endtask

 task run();
  forever begin
    mbx.get(tr); // Get transaction from generator
    vif.a <= tr.a; // Random  A for Set DUT  input A
    vif.b <= tr.b; // Random  B for  Set DUT input B
    @(posedge vif.clk); // Wait for the next clock edge
    tr.result = vif.result; // Capture DUT output
    tr.display("DRV"); // Display transaction information
  end
endtask
  
  
endclass
//////////////////////////////////   Monitor 

class monitor;
  transaction tr; // Define a transaction object
  mailbox #(transaction) mbx; //  mailbox to send data to the scoreboard
  virtual dff_if vif; // Virtual interface for DUT

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx; // Initialize the mailbox for sending data to the scoreboard
  endfunction
  
task run();
  tr = new(); // Create a new transaction
  forever begin
   repeat(2)@(posedge vif.clk); // // Wait for 2 clock cycles
    tr.result = vif.result; // Capture DUT output
    mbx.put(tr); // Send transaction to scoreboard
    tr.display("MON"); // Display transaction information
  end
endtask
  
endclass
///////////////////////////    Scoreboard 

class scoreboard;
  transaction tr; // Define a transaction object
  transaction trref; // Define a reference transaction object for comparison
  mailbox #(transaction) mbx; // mailbox to receive data from the driver
  mailbox #(transaction) mbxref; //mailbox to receive reference data from the generator
  event sconext; // Event to signal completion of scoreboard work

  function new(mailbox #(transaction) mbx, mailbox #(transaction) mbxref);
    this.mbx = mbx; // Receiving data from the driver
    this.mbxref = mbxref; // Receiving reference data from the generator
  endfunction

 task run();
  forever begin
    mbx.get(tr); // Get transaction from monitor
    mbxref.get(trref); // Get reference transaction from generator
    tr.display("SCO"); // Display monitor transaction
    trref.display("REF"); // Display reference transaction
    $display("[SCO] : ACTUAL RESULT : %4b, EXPECTED RESULT : %4b",      tr.result, (trref.a & trref.b));
    
     if (tr.result === trref.result) // Use case equality (===) for 4-state logic comparison
      $display("[SCO] : DATA MATCHED");
    else
      $display("[SCO] : DATA MISMATCHED");
    $display("-------------------------------------------------");
    ->sconext; // Signal completion
  end
endtask
endclass
///////////////      Environment
class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  event next;

  mailbox #(transaction) gdmbx; // Generator -> Driver
  mailbox #(transaction) msmbx; // Monitor -> Scoreboard
  mailbox #(transaction) mbxref; // Generator -> Scoreboard

  virtual dff_if vif;

  function new(virtual dff_if vif);
    gdmbx = new();
    mbxref = new();
    gen = new(gdmbx, mbxref);
    drv = new(gdmbx);
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx, mbxref);
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
    gen.sconext = next;
    sco.sconext = next;
  endfunction

  task pre_test();
    drv.reset();
  endtask

  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask

  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask

  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

/////////////////                TestBeench

module tb;
  dff_if vif(); // Create DUT interface

  dff dut(vif); // Instantiate DUT

  initial begin
    vif.clk <= 0; // Initialize clock signal
  end

  always #10 vif.clk <= ~vif.clk; // Toggle the clock every 10 time units

  environment env; // Declare environment instance

  initial begin
    env = new(vif); // Initialize the environment with the DUT interface
    env.gen.count = 30; // Set the generator's stimulus count
    env.run(); // Run the environment
  end

  initial begin
    $dumpfile("dump.vcd"); // Specify the VCD dump file
    $dumpvars; // Dump all variables
  end
endmodule
