`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.06.2025 18:36:07
// Design Name: 
// Module Name: clock_gating_FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Clock Gating FSM with Safe Implementation
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created with Improvements
// Additional Comments: 
// - Improved clock gating safety
// - Better synthesis compatibility
// - Enhanced testbench
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.06.2025 18:36:07
// Design Name: 
// Module Name: clock_gating_FSM
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Clock Gating FSM with Safe Implementation
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created with Synthesis Fixes
// Additional Comments: 
// - Fixed synthesis warnings
// - Removed unused modules
// - Improved synthesis compatibility
//////////////////////////////////////////////////////////////////////////////////

// Clock Gating FSM - Synthesis-Clean Implementation
`timescale 1ns / 1ps

//=============================================================================
// Main Clock Gating FSM Module
//=============================================================================
module clock_gating_FSM(
    input wire clk,
    input wire rst,
    input wire trig,
    output reg enable_clk,
    output wire gated_clk,
    output wire [1:0] current_state
);
    
    // State encoding - Using Gray code for better switching
    localparam IDLE   = 2'b00;
    localparam ACTIVE = 2'b01;
    localparam WAIT   = 2'b11;
    localparam SLEEP  = 2'b10;
    
    // Internal state registers
    reg [1:0] state, next_state;
    reg enable_clk_ff;  // Registered enable for safer clock gating
    
    // Sequential logic - State register
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Combinational logic - Next state logic
    always @(*) begin
        case(state)
            IDLE:   next_state = trig ? ACTIVE : IDLE;
            ACTIVE: next_state = trig ? ACTIVE : WAIT;
            WAIT:   next_state = trig ? ACTIVE : SLEEP;
            SLEEP:  next_state = trig ? ACTIVE : SLEEP;
            default: next_state = IDLE;  // Safe default
        endcase
    end
    
    // Output logic - Moore FSM (output depends only on current state)
    always @(*) begin
        case(state)
            ACTIVE, WAIT: enable_clk = 1'b1;
            IDLE, SLEEP:  enable_clk = 1'b0;
            default:      enable_clk = 1'b0;  // Safe default
        endcase
    end
    
    // Safe clock gating using registered enable (eliminates glitches)
    always @(posedge clk or posedge rst) begin
        if (rst)
            enable_clk_ff <= 1'b0;
        else
            enable_clk_ff <= enable_clk;
    end
    
    // Generate gated clock - Use registered enable for safety
    assign gated_clk = clk & enable_clk_ff;
    assign current_state = state;
    
endmodule

//=============================================================================
// Example Load Module (demonstrates clock gating benefit)
//=============================================================================
module example_load(
    input wire clk,
    input wire rst,
    input wire enable,
    output reg [7:0] counter
);
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            counter <= 8'b0;
        else if (enable)
            counter <= counter + 1;
    end
    
endmodule

//=============================================================================
// Power Monitor Module (estimates power savings)
//=============================================================================
module power_monitor(
    input wire clk,
    input wire rst,
    input wire normal_clk_active,
    input wire gated_clk_active,
    output reg [15:0] normal_clk_cycles,
    output reg [15:0] gated_clk_cycles,
    output wire [7:0] power_savings_percent
);
    
    // Count clock cycles
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            normal_clk_cycles <= 16'b0;
            gated_clk_cycles <= 16'b0;
        end else begin
            if (normal_clk_active)
                normal_clk_cycles <= normal_clk_cycles + 1;
            if (gated_clk_active)
                gated_clk_cycles <= gated_clk_cycles + 1;
        end
    end
    
    // Calculate power savings percentage (simplified)
    wire [15:0] savings = normal_clk_cycles - gated_clk_cycles;
    assign power_savings_percent = (normal_clk_cycles > 0) ? 
                                   (savings * 100 / normal_clk_cycles) : 8'b0;
    
endmodule

//=============================================================================
// Top Module - Complete System with Power Monitoring
//=============================================================================
module clock_gating_top(
    input wire clk,
    input wire rst,
    input wire trig,
    output wire [7:0] counter_normal,
    output wire [7:0] counter_gated,
    output wire [1:0] fsm_state,
    output wire clock_enabled,
    output wire [7:0] power_savings_percent,
    output wire [15:0] normal_cycles,
    output wire [15:0] gated_cycles
);
    
    wire gated_clk;
    wire enable_clk;
    wire [15:0] normal_clk_cycles, gated_clk_cycles;
    
    // Clock gating FSM
    clock_gating_FSM fsm_inst (
        .clk(clk),
        .rst(rst),
        .trig(trig),
        .enable_clk(enable_clk),
        .gated_clk(gated_clk),
        .current_state(fsm_state)
    );
    
    // Normal counter (always running)
    example_load normal_counter (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .counter(counter_normal)
    );
    
    // Gated counter (only runs when clock is enabled)
    example_load gated_counter (
        .clk(gated_clk),
        .rst(rst),
        .enable(1'b1),
        .counter(counter_gated)
    );
    
    // Power monitoring
    power_monitor pwr_mon (
        .clk(clk),
        .rst(rst),
        .normal_clk_active(1'b1),
        .gated_clk_active(enable_clk),
        .normal_clk_cycles(normal_clk_cycles),
        .gated_clk_cycles(gated_clk_cycles),
        .power_savings_percent(power_savings_percent)
    );
    
    // Output assignments
    assign clock_enabled = enable_clk;
    assign normal_cycles = normal_clk_cycles;
    assign gated_cycles = gated_clk_cycles;
    
endmodule

//=============================================================================
// Comprehensive Testbench
//=============================================================================
module tb_clock_gating;
    
    reg clk, rst, trig;
    wire [7:0] counter_normal, counter_gated;
    wire [1:0] fsm_state;
    wire clock_enabled;
    wire [7:0] power_savings;
    wire [15:0] normal_cycles, gated_cycles;
    
    // Instantiate top module
    clock_gating_top dut (
        .clk(clk),
        .rst(rst),
        .trig(trig),
        .counter_normal(counter_normal),
        .counter_gated(counter_gated),
        .fsm_state(fsm_state),
        .clock_enabled(clock_enabled),
        .power_savings_percent(power_savings),
        .normal_cycles(normal_cycles),
        .gated_cycles(gated_cycles)
    );
    
    // Clock generation - 100MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;
    
    // State names for display
    reg [63:0] state_name;
    always @(*) begin
        case(fsm_state)
            2'b00: state_name = "IDLE   ";
            2'b01: state_name = "ACTIVE ";
            2'b11: state_name = "WAIT   ";
            2'b10: state_name = "SLEEP  ";
            default: state_name = "UNKNOWN";
        endcase
    end
    
    // Test sequence
    initial begin
        // Initialize
        rst = 1;
        trig = 0;
        
        #20 rst = 0;
        
        $display("\n=== Clock Gating FSM Test ===");
        $display("Testing Clock Gating Implementation");
        
        // Test sequence: Basic operation
        #10 trig = 1;  // Go to ACTIVE
        #30 trig = 0;  // Go to WAIT
        #20;           // Go to SLEEP
        #40;           // Stay in SLEEP
        
        #10 trig = 1;  // Wake up to ACTIVE
        #20 trig = 0;  // Go to WAIT
        #10 trig = 1;  // Back to ACTIVE
        #30 trig = 0;  // Go to WAIT then SLEEP
        #50;           // Stay in SLEEP
        
        $display("\n=== Test Complete ===");
        $display("Final Power Savings: %0d%%", power_savings);
        $display("Normal Cycles: %0d, Gated Cycles: %0d", normal_cycles, gated_cycles);
        $finish;
    end
    
    // Monitor output using $monitor
    initial begin
        $monitor("Time=%0t | State=%s | Trig=%b | ClkEn=%b | Normal=%3d | Gated=%3d | Savings=%3d%%", 
                 $time, state_name, trig, clock_enabled, counter_normal, counter_gated, power_savings);
    end
    
    // Waveform dump for debugging
    initial begin
        $dumpfile("clock_gating.vcd");
        $dumpvars(0, tb_clock_gating);
    end
    
endmodule