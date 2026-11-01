`timescale 1ns / 1ps

module sync_fifo(
input clk,rst,wr_en,rd_en,
input [7:0]data_in,
output reg [7:0]data_out,
output reg full,empty
    );

reg [7:0] mem [0:15] ;
reg [3:0]wr_ptr,rd_ptr;
reg [4:0] count;         //the current no of entries of fifo
reg [4:0] next_count;   //the no of entries of fifo on next clk edge

//next count logic is used as we are using non blocking assignments
always@(*)
begin
    if(wr_en && !full && (!rd_en || empty))       //write accepted and read rejected
    begin
    next_count=count+1'b1;
    end
    
    else if(rd_en && !empty && (!wr_en || full))  //read accepted and write rejected
    begin
    next_count=count-1'b1;
    end
    
    else
    begin
    next_count=count;                       
    end
end

always @(posedge clk)
begin
if(rst)
begin
full<=0;
empty<=1;
wr_ptr<=0;
rd_ptr<=0;
count<=0;
data_out<=0;
end
else
begin
    // write operation
    if(wr_en && !full)         //write accepted
    begin
      mem[wr_ptr]<=data_in;
      wr_ptr<= wr_ptr+1'b1;
    end
    
    // read operation
    if(rd_en && !empty)        //read accepted
    begin
    data_out<=mem[rd_ptr];
    rd_ptr<=rd_ptr+1'b1;
    end
    
    count<=next_count;
    
    //updating full and empty flags
    if(next_count==0)
    begin
      empty<=1;
      full<=0;
    end
    
    else if(next_count==16)
    begin
    full<=1;
    empty<=0;
    end
    
    else
    begin
    full<=0;
    empty<=0;
    end
end
end
endmodule
