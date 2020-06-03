
// Top level system including MIPS and memories


module top  (input   logic 	 clk, reset,            
	     output  logic[31:0] writedata, dataadr,     
	     output  logic memwrite,
	     output  logic zero,
	     output  logic lui,
	     output  logic[31:0] instr,  
	     output  logic[31:0] eventual_result,  
	     output  logic[31:0] pc);  

   logic [31:0] readdata;    

   // instantiate processor and memories  
   mips mips (clk, reset, pc, instr, memwrite, dataadr, writedata, readdata, zero, lui, eventual_result);  
   imem imem (pc[7:2], instr);  
   dmem dmem (clk, memwrite, dataadr, writedata, readdata);

endmodule



// External data memory used by MIPS single-cycle processor

module dmem (input  logic        clk, we,
             input  logic[31:0]  a, wd,
             output logic[31:0]  rd);

   logic  [31:0] RAM[63:0];
  
   assign rd = RAM[a[31:2]];    // word-aligned  read (for lw)

   always_ff @(posedge clk)
     if (we)
       RAM[a[31:2]] <= wd;      // word-aligned write (for sw)

endmodule



// External instruction memory used by MIPS single-cycle
// processor. It models instruction memory as a stored-program 
// ROM, with address as input, and instruction as output


module imem ( input logic [5:0] addr, output logic [31:0] instr);

// imem is modeled as a lookup table, a stored-program byte-addressable ROM
	always_comb
	   case ({addr,2'b00})		   	// word-aligned fetch
//		address		instruction
//		-------		-----------
        8'h00: instr = 32'h20020005;  	 // addi $v0, $zero, 5
		8'h04: instr = 32'h2003000c;  	 // addi $v1, $zero, 12
		8'h08: instr = 32'h2067fff7;     // addi $a3, $v1, -9
		8'h0c: instr = 32'h00e22025;  	 // or $a0, $a3, $v0
		8'h10: instr = 32'h00642824;     // and $a1, $v1, $a0
		8'h14: instr = 32'h00a42820;     // add $a1, $a1, $a0
		8'h18: instr = 32'h10a7000a;     // beq $a1, $a3, 0x000A
		8'h1c: instr = 32'h0064202a;     // slt $a0, $v1, $a0
		8'h20: instr = 32'h10800001;     // beq $a0, $zero, 0x0001
		8'h24: instr = 32'h20050000;     // addi $a1, $zero, 0
		8'h28: instr = 32'h00e2202a;     // slt $a0, $a3, $v0
		8'h2c: instr = 32'h00853820;     // add $a3, $a0, $a1
		8'h30: instr = 32'h00e23822;     // sub $a3, $a3, $v0
		8'h34: instr = 32'hac670044;     // sw $a3, 68($v1)
		8'h38: instr = 32'h8c020050;     // lw $v0, 80($zero)
		8'h3c: instr = 32'h08000011;     // j 0x0000011
		8'h40: instr = 32'h20020001;     // addi $v0, $zero, 0x0001 
		8'h44: instr = 32'hac020054;     // sw $v0, 84($zero) 
        // ======================================================
        8'h48: instr = 32'h20020005;  	 // addi $v0, $zero, 5
		8'h4c: instr = 32'h2003000c;  	 // addi $v1, $zero, 12
		8'h50: instr = 32'h4004025a;     // lui $a0, 0x0001
	    // ======================================================
		8'h54: instr = 32'h08000015;     // j 0x0000015 --> 54, so it will loop here
	    default:  instr = {32{1'bx}};	// unknown address
	   endcase
endmodule


// single-cycle MIPS processor, with controller and datapath

module mips (input  logic        clk, reset,
             output logic[31:0]  pc,
             input  logic[31:0]  instr,
             output logic        memwrite,
             output logic[31:0]  aluout, writedata,
             input  logic[31:0]  readdata,
             output  logic zero,
             output  logic lui,
             output  logic[31:0] eventual_result);

  logic        memtoreg, pcsrc, alusrc, regdst, regwrite, jump;
  logic [2:0]  alucontrol;

  controller c (instr[31:26], instr[5:0], zero, memtoreg, memwrite, pcsrc,
                        alusrc, regdst, regwrite, jump, alucontrol, lui);

  datapath dp (clk, reset, memtoreg, pcsrc, alusrc, regdst, regwrite, jump,
                          alucontrol, zero, lui, pc, instr, aluout, writedata, eventual_result, readdata);

endmodule
module controller(input  logic[5:0] op, funct,
                  input  logic     zero,
                  output logic     memtoreg, memwrite,
                  output logic     pcsrc, alusrc,
                  output logic     regdst, regwrite,
                  output logic     jump,
                  output logic[2:0] alucontrol,
                  output logic lui);

   logic [1:0] aluop;
   logic       branch;

   maindec md (op, memtoreg, memwrite, branch, alusrc, regdst, regwrite, 
		 jump, aluop, lui);

   aludec  ad (funct, aluop, alucontrol);

   assign pcsrc = branch & zero;

endmodule

module maindec (input logic[5:0] op, 
	              output logic memtoreg, memwrite, branch,
	              output logic alusrc, regdst, regwrite, jump,
	              output logic[1:0] aluop,
	              output logic lui );
	              
   logic [9:0] controls;

   assign {regwrite, regdst, alusrc, branch, memwrite,
                memtoreg,  aluop, jump, lui} = controls;

  always_comb
    case(op)
      6'b000000: controls <= 10'b1100001000; // R-type
      6'b100011: controls <= 10'b1010010000; // LW
      6'b101011: controls <= 10'b0010100000; // SW
      6'b000100: controls <= 10'b0001000100; // BEQ
      6'b001000: controls <= 10'b1010000000; // ADDI
      6'b000010: controls <= 10'b0000000010; // J
      6'b010000: controls <= 10'b10x00xxx01; // LUI
      default:   controls <= 9'bxxxxxxxxx; // illegal op
    endcase
endmodule

module aludec (input    logic[5:0] funct,
               input    logic[1:0] aluop,
               output   logic[2:0] alucontrol);
  always_comb
    case(aluop)
      2'b00: alucontrol  = 3'b010;  // add  (for lw/sw/addi)
      2'b01: alucontrol  = 3'b110;  // sub   (for beq)
      default: case(funct)          // R-TYPE instructions
          6'b100000: alucontrol  = 3'b010; // ADD
          6'b100010: alucontrol  = 3'b110; // SUB
          6'b100100: alucontrol  = 3'b000; // AND
          6'b100101: alucontrol  = 3'b001; // OR
          6'b101010: alucontrol  = 3'b111; // SLT
          default:   alucontrol  = 3'bxxx; // ???
        endcase
    endcase
endmodule

module datapath (input  logic clk, reset, memtoreg, pcsrc, alusrc, regdst,
                 input  logic regwrite, jump, 
		 input  logic[2:0]  alucontrol, 
                 output logic zero, 
                 output logic lui, 
		 output logic[31:0] pc, 
	         input  logic[31:0] instr,
                 output logic[31:0] aluout, writedata,  
                 output logic[31:0] eventual_result, 
	         input  logic[31:0] readdata);

  logic [4:0]  writereg;
  logic [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  logic [31:0] signimm, signimmsh, srca, srcb, result, lui_result;
 
  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(signimm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc,
                      pcnextbr);
  mux2 #(32)  pcmux(pcnextbr, {pcplus4[31:28], 
                    instr[25:0], 2'b00}, jump, pcnext);

   signext se (instr[15:0], signimm);
   zeroToEnd zte (instr[15:0], lui_result); 

   mux2 #(5)   wrmux (instr[20:16], instr[15:11], regdst, writereg);
   mux2 #(32)  resmux (aluout, readdata, memtoreg, result);
   mux2 #(32)  luimux (result, lui_result, lui, eventual_result);
   
   // register file logic
   regfile     rf (clk, regwrite, instr[25:21], instr[20:16], writereg,
                   eventual_result, srca, writedata);
    
    
    
  // ALU logic
   mux2 #(32)  srcbmux (writedata, signimm, alusrc, srcb);
   alu         alu (srca, srcb, alucontrol, aluout, zero);

endmodule

module zeroToEnd (input  logic[15:0] a,
                  output logic[31:0] y);
              
  assign y = {a, 16'h0000};    // sign-extends 16-bit a
endmodule

module regfile (input    logic clk, we3, 
                input    logic[4:0]  ra1, ra2, wa3, 
                input    logic[31:0] wd3, 
                output   logic[31:0] rd1, rd2);

  logic [31:0] rf [31:0];

  // three ported register file: read two ports combinationally
  // write third port on rising edge of clock. Register0 hardwired to 0.

  always_ff@(posedge clk)
     if (we3) 
         rf [wa3] <= wd3;	

  assign rd1 = (ra1 != 0) ? rf [ra1] : 0;
  assign rd2 = (ra2 != 0) ? rf[ ra2] : 0;

endmodule


module alu(input  logic [31:0] a, b, 
           input  logic [2:0]  alucont, 
           output logic [31:0] result,
           output logic zero);    
           assign zero = 0; 
    always_comb
        case(alucont)
            3'b000: result = a&b;
            3'b001: result = a|b; 
            3'b010: result = a+b;
            3'b100: result = a&~b;
            3'b101: result = a|~b;
            3'b110: begin result = a-b; zero = a==b ? 1 : 0;  end
            3'b111: result = a < b ? 1 : 0;
        endcase  
endmodule



module adder (input  logic[31:0] a, b,
              output logic[31:0] y);
     
     assign y = a + b;
endmodule

module sl2 (input  logic[31:0] a,
            output logic[31:0] y);
     
     assign y = {a[29:0], 2'b00}; // shifts left by 2
endmodule

module signext (input  logic[15:0] a,
                output logic[31:0] y);
              
  assign y = {{16{a[15]}}, a};    // sign-extends 16-bit a
endmodule

// parameterized register
module flopr #(parameter WIDTH = 8)
              (input logic clk, reset, 
	       input logic[WIDTH-1:0] d, 
               output logic[WIDTH-1:0] q);

  always_ff@(posedge clk, posedge reset)
    if (reset) q <= 0; 
    else       q <= d;
endmodule


// paramaterized 2-to-1 MUX
module mux2 #(parameter WIDTH = 8)
             (input  logic[WIDTH-1:0] d0, d1,  
              input  logic s, 
              output logic[WIDTH-1:0] y);
  
   assign y = s ? d1 : d0; 
endmodule

