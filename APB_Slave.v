module APB_Slave#( parameter DWIDTH = 32, AWIDTH = 5)           //Size of Address Bus
(   input                                      PCLK,            //Rising Edge Clock
    input                                   PRESETn,            //Active Low Reset
    input                                     PSELx,            //Selecting slave(in our case there is only one slave)
    input                                   PENABLE,            //Enable for second cycle of transfer
    input                        [AWIDTH-1:0] PADDR,            //APB Address Bus
    input                                    PWRITE,            //Flag=1 for write and Flag=0 for read
    input                       [DWIDTH-1:0] PWDATA,            //Data to be written
    
    output reg                  [DWIDTH-1:0] PRDATA,            //Read Data from MASTER
    output                                   PREADY,            //Completer is ready
    output                                   PSLVERR            //Transfer Error given by Completer
);  
    localparam                  [2:0] IDLE   = 3'b000;          //IDLE State
    localparam                  [2:0] READY  = 3'b001;          //READY State
    localparam                  [2:0] READ   = 3'b010;          //READ State
    localparam                  [2:0] WRITE  = 3'b011;          //WRITE State
    localparam                  [2:0] ERROR  = 3'b100;          //ERROR State
    
    reg                           [2:0] current_state;          //Current State of FSM
    reg                           [2:0]    next_state;          //Next State of FSM
    reg           [DWIDTH-1:0] mem_arr[2**AWIDTH-1:0];          // Memory Peripheral 
    wire          [AWIDTH-1:0]           base_address;          // base address of memory block to be used as peripheral
    wire                                   PADDR_VALID;         // Address validity according to base address
    
always @(posedge PCLK,negedge PRESETn)
    //current_state <= (!PRESETn)? IDLE: next_state; // gives error on compilation
    if(!PRESETn)
        current_state <= IDLE; // Reset State
    else
        current_state <= next_state; // next state calculated by combinational always block
        
always @(*)
begin
    case(current_state) // condtion for current state
        IDLE : 
                next_state <= PSELx? READY:IDLE; // checking if current SLAVe is selected or not
        READY: 
                next_state <= !PSELx?                IDLE  // reset state if not selected
                            : !PADDR_VALID?         ERROR // if requested data address is not valid go to error     
                            : !PENABLE?             READY // if enabled check for write signal
                            : !PWRITE?              READ
                            :                       WRITE;// remain in same state if not enabled
        WRITE: 
                next_state <= !PSELx?                IDLE  // reset state if not selected 
                            : !PENABLE?             READY // if write acces is complete check if still selected
                            :                       WRITE;// if write acces is not complete remain in same state
        READ : 
                next_state <= !PSELx?                IDLE  // reset state if not selected 
                            : !PENABLE?             READY // if write acces is complete check if still selected
                            :                       READ; // if write acces is not complete remain in same state
        ERROR: 
                next_state <= PSELx&!PADDR_VALID?   ERROR // if requested data address is not valid go to error 
                            : PSELx?                READY // go to ready state if selected and addr is valid
                            :                       IDLE; // reset state if not selected 
        default:
                next_state <= IDLE;
    endcase
end
always @(*)
begin
    if(current_state==WRITE)
        mem_arr[PADDR] <= PWDATA;
            
    if(current_state==READ)
        PRDATA <= mem_arr[PADDR];
    else
        PRDATA<= {(2**AWIDTH-1){1'bz}};
end
    assign base_address[AWIDTH-1:0] = 'b0;
    assign PADDR_VALID = (PADDR>base_address) || (PADDR<(2**AWIDTH-1+base_address));
    assign PREADY= (current_state==READY);
    assign PSLVERR= (current_state==ERROR);
endmodule
