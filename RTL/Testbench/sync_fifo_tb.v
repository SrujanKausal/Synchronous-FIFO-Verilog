`timescale 1ns / 1ps

module sync_fifo_tb;
reg clk,rst,wr_en,rd_en;
reg [4:0]expected_count;           //it counts the entries which will be independent of dut.count
reg expected_full;
reg expected_empty;
reg [7:0]data_in;
reg [7:0] expected_data [0:15];
reg [3:0]expected_wr,expected_rd;
wire [7:0]data_out;
wire full,empty;
integer i;
reg [7:0]value1;
reg [7:0]expected;
reg [4:0]ec;                    //to get the expected count before clk
reg [7:0] previous_data;        //for output retention test

//module instantiation
sync_fifo dut(.clk(clk),.rst(rst),.wr_en(wr_en),.rd_en(rd_en),.data_in(data_in),
.data_out(data_out),.full(full),.empty(empty));

//clock generation
initial clk=0;
always #5 clk = ~clk;

//checker for fifo
task check_fifo;
begin
    if(expected_count==0)
    begin
      expected_empty=1;
      expected_full=0;
    end
    
    else if(expected_count==16)
    begin
    expected_full=1;
    expected_empty=0;
    end
    
    else
    begin
    expected_full=0;
    expected_empty=0;
    end

   if(dut.count===expected_count && full===expected_full && empty===expected_empty)
   begin
     $display("PASS,count:%d,empty:%d,full:%d",dut.count,empty,full);
   end
   else
   begin
     $display("FAIL,count:%d,empty:%d,full:%d",dut.count,empty,full);
     $finish;
   end
   end
endtask

//for writing data
task write_byte;
input [7:0]value;
begin
@(negedge clk);   //prepares the inputs
wr_en=1;
rd_en=0;
data_in=value;

@(posedge clk);  //fifo accepted the write 
if(wr_en && (expected_count<16))
begin
expected_data[expected_wr]=data_in;
expected_wr=expected_wr+1'b1;
end
#1           //waiting for non blocking assignments to be evaluated
check_fifo();
end
endtask

//for reading data
task read_byte;
begin
@(negedge clk);    //prepares the inputs
rd_en=1;
wr_en=0;
ec=expected_count;
previous_data=data_out;

@(posedge clk);    //fifo accepted the read
#1                 //waiting for non blocking assignments to be evaluated
if(ec>0)
begin

if(data_out === expected_data[expected_rd])
begin
$display("PASS: data_out is: %d correct",data_out);
end  
else
begin
$display("FAIL: incorrect data_out is: %d",data_out);
$finish;
end

end

else
begin

if(data_out === previous_data)
$display("PASS: output retained its previous value: %d",data_out);
else
begin
$display("FAIL: output retention failed");
$finish;
end

end

//incrementing read pointer
if(rd_en && ec>0)
begin
expected_rd=expected_rd+1'b1;
end
check_fifo();
end
endtask

//for simultaneously read and write
task simultaneous_read_write; 
input [7:0]value;
begin 

@(negedge clk);      //prepares the inputs
wr_en=1;
rd_en=1;
data_in=value;
ec = expected_count;

@(posedge clk);  //fifo accepted the write and read
#1           //waiting for non blocking assignments to be evaluated

//read part
if(ec>0)
begin
  if(data_out === expected_data[expected_rd])
   begin
    $display("PASS: data_out is: %d correct",data_out);
   end  
   else
   begin
     $display("FAIL: incorrect data_out is: %d",data_out);
     $finish;
   end
end

//write part
if(wr_en && rd_en && ( ec <16))
begin
expected_data[expected_wr]=data_in;
expected_wr=expected_wr+1'b1;
end
//read part
if(wr_en && rd_en && ( ec >0))
begin
expected_rd=expected_rd+1'b1;
end
check_fifo();
end
endtask

//reference model
always@(posedge clk)
begin
if(rst)
begin
expected_count <= 0;
expected_full  <= 0;
expected_empty <= 1;
expected_wr<=0;
expected_rd<=0;
end
else
begin
    if(wr_en && (expected_count<16) && (!rd_en || expected_count==0))       //write accepted and read rejected
    begin
    expected_count<=expected_count+1'b1;
    end
    
    else if(rd_en && (expected_count>0) && (!wr_en || expected_count==16))  //read accepted and write rejected
    begin
     expected_count<= expected_count-1'b1;
    end
end
end

initial
begin
rst=1;
rd_en=0;
wr_en=0;
data_in=8'b0;
expected_count=0;
expected_full=0;
expected_empty=1;
expected_wr=0;
expected_rd=0;
#20
rst=0;


///overflow test

for(i=0;i<17;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end

@(negedge clk);
wr_en=0;

for(i=0;i<16;i=i+1)
begin
read_byte();
end


//wrap around test

for(i=0;i<12;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end

@(negedge clk);
wr_en=0;

for(i=0;i<12;i=i+1)
begin
read_byte();
end

@(negedge clk);
rd_en=0;

for(i=0;i<8;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end

@(negedge clk);
wr_en=0;

for(i=0;i<8;i=i+1)
begin
read_byte();
end

@(negedge clk);
rd_en=0;


//simultaneous read and write

for(i=0;i<3;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end
simultaneous_read_write(8'hD4);
for(i=0;i<3;i=i+1)
begin
read_byte();
end
@(negedge clk);
wr_en=0;
rd_en=0;


//for empty

simultaneous_read_write(8'hD4);
@(negedge clk);
wr_en=0;
rd_en=0;


//for full

for(i=0;i<16;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end

@(negedge clk);
wr_en=0;

simultaneous_read_write(8'hD4);
@(negedge clk);
wr_en=0;
rd_en=0;

for(i=0;i<15;i=i+1)
begin
read_byte();
end

@(negedge clk);
rd_en=0;


//rst  and recovery test

for(i=0;i<3;i=i+1)
begin
value1=$random;
expected=value1;
write_byte(expected);
end
@(negedge clk);
wr_en=0;
rst=1;
@(posedge clk);
#1
check_fifo();

@(negedge clk);
rst=0;
write_byte(8'hA5);
@(negedge clk);
wr_en=0;

read_byte();
@(negedge clk);
rd_en=0;


//output retention

write_byte(8'hA5);
@(negedge clk);
wr_en=0;

read_byte();
@(negedge clk);
rd_en=0;

read_byte();
@(negedge clk);
rd_en=0;


//randomized stress test
for(i=0; i<1000; i=i+1)
begin
    case(($random & 32'h7fffffff) % 3)         //$random can generate negative number 
                                               //so we are masking the sign bit

        0: write_byte($random);

        1: read_byte();

        2: simultaneous_read_write($random);

    endcase
end
//for draining the data left
while(expected_count > 0)
begin
    read_byte();
end
$display("THE OPERATION IS COMPLETED");
$finish;
end
endmodule
