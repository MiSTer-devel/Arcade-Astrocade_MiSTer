`timescale 1ns / 1ps

//MIT License
//
//Copyright (c) 2020 Mike Field
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

module second_order_dac(
  input wire i_clk,
  input wire i_res,
  input wire i_ce,
  input wire [15:0] i_func, 
  output wire o_DAC
);

  reg this_bit;
 
  reg [19:0] DAC_acc_1st;
  reg [19:0] DAC_acc_2nd;
  reg [19:0] i_func_extended;
   
  assign o_DAC = this_bit;

  always @(*)
     i_func_extended = {i_func[15],i_func[15],i_func[15],i_func[15],i_func};
    
  always @(posedge i_clk or negedge i_res)
    begin
      if (i_res==0)
        begin
          DAC_acc_1st<=16'd0;
          DAC_acc_2nd<=16'd0;
          this_bit = 1'b0;
        end
      else if(i_ce == 1'b1) 
        begin
          if(this_bit == 1'b1)
            begin
              DAC_acc_1st = DAC_acc_1st + i_func_extended - (2**15);
              DAC_acc_2nd = DAC_acc_2nd + DAC_acc_1st     - (2**15);
            end
          else
            begin
              DAC_acc_1st = DAC_acc_1st + i_func_extended + (2**15);
              DAC_acc_2nd = DAC_acc_2nd + DAC_acc_1st + (2**15);
            end
          // When the high bit is set (a negative value) we need to output a 0 and when it is clear we need to output a 1.
          this_bit = ~DAC_acc_2nd[19];
        end
    end
endmodule