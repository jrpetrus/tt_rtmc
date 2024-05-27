/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

// SPI to Register bus controller.

module rtmc_spi #(
    parameter ADDR_W = 8,
    parameter DATA_W = 16
)
(
    // Core clock and reset
    input  logic clk,
    input  logic rst_n,

    // SPI interface to pins
    input  logic sck,
    input  logic cs_n,
    input  logic sdi,
    output logic sdo,

    // Register interface
    output logic [ADDR_W-1:0] reg_addr,
    output logic [DATA_W-1:0] reg_wdat,
    output logic reg_wr,
    output logic reg_rd,
    input  logic [DATA_W-1:0] reg_rdat,
    input  logic reg_ack
);
    // shift reg width
    localparam N_BITS = 8;

    // SPI RW protocol.
    localparam SPI_OP_RESULT_W = 8;
    
    // Op codes
    localparam logic [SPI_OP_RESULT_W-1:0] O_NOP = 8'h0;
    localparam logic [SPI_OP_RESULT_W-1:0] O_RD = 8'h01;
    localparam logic [SPI_OP_RESULT_W-1:0] O_WR = 8'h02;

    // Result codes. R_BUSY currently not used as low-level
    // spi_rxtx will output a zero if no data available.
    // localparam logic [SPI_OP_RESULT_W-1:0] R_BUSY = 8'h00;
    localparam logic [SPI_OP_RESULT_W-1:0] R_ACK = 8'h01;
    localparam logic [SPI_OP_RESULT_W-1:0] R_ACK_DATA = 8'h02;

    // max outstanding bytes to count or buffer
    localparam ADDR_BYTES = 1; 
    localparam DATA_BYTES = 2; 
    localparam bit [$clog2(ADDR_BYTES + DATA_BYTES):0] N_BYTES = ADDR_BYTES + DATA_BYTES;

    // Register I/O state machine.
    enum logic [2:0] {
        IDLE = 'd0,
        ADDR = 'd1,
        WRITE = 'd2,
        ACK = 'd3,
        RESULT = 'd4
    } state, next_state;

    // op and result bytes.
    logic [SPI_OP_RESULT_W-1:0] op;
    logic [DATA_W-1:0] rdat;

    // byte counter
    logic [$clog2(N_BYTES):0] byte_count;
    logic byte_count_done;

    // SPI Rx Data
    logic[N_BITS-1:0] din;
    logic din_valid;

    // SPI Tx Data
    logic[N_BITS-1:0] dout;
    logic dout_valid;
    logic dout_ack;

    // Byte count is done when it is zero.
    always_comb
        byte_count_done = ~|byte_count;

    // Registed state machine.
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Combinatorial next state logic.
    always_comb begin
        next_state = state;
        case(state)
            IDLE: begin
                if(din_valid && din != O_NOP)
                    next_state = ADDR;
            end

            ADDR: begin
                if(din_valid) begin
                    case(op)
                        O_WR: next_state = WRITE;
                        O_RD: next_state = ACK;
                        default: next_state = IDLE;
                    endcase
                end
            end

            WRITE: begin
                if(din_valid && byte_count_done)
                    next_state = ACK;
            end

            ACK: begin
                if((reg_rd || reg_wr) && reg_ack)
                    next_state = RESULT;
            end
            
            RESULT: begin
                if(byte_count_done & dout_valid && dout_ack)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            op <= O_NOP;
            byte_count <= '0;
            reg_rd <= '0;
            reg_wr <= '0;
            dout_valid <= '0;
        end
        else begin
            case(state)
                IDLE: begin
                    // Wait for the OP byte.
                    if(din_valid && din != O_NOP) begin
                        op <= din;
                        byte_count <= 'd1;
                    end
                end

                ADDR: begin
                    // Wait for the ADDR byte.
                    if(din_valid) begin
                        reg_addr <= din;
                        reg_rd <= op == O_RD;
                        byte_count <= DATA_BYTES - 1'b1;
                    end
                end

                WRITE: begin
                    // Wait for DATA_BYTES to present on wdat.
                    if(din_valid) begin
                        reg_wdat <= {reg_wdat[N_BITS-1:0], din};
                        byte_count <= byte_count - 1'b1;
                        reg_wr <= byte_count_done;
                    end
                end

                ACK: begin
                    // Read is ACK'd, save rdat.
                    if(reg_rd && reg_ack) begin
                        rdat <= reg_rdat;
                        reg_rd <= '0;
                        byte_count <= N_BYTES - 1;
                        dout <= R_ACK_DATA;
                        dout_valid <= '1;
                    end

                    // Write is ACK'd.
                    if(reg_wr && reg_ack) begin
                        reg_wr <= '0;
                        byte_count <= '0;
                        dout <= R_ACK;
                        dout_valid <= '1;
                    end
                end
                
                RESULT: begin
                    // Result count can be 1 or 3 bytes.
                    if(dout_valid && dout_ack) begin
                        byte_count <= byte_count - 1'b1;
                        dout_valid <= ~byte_count_done;
                        dout <= rdat[$left(rdat):N_BITS];
                        rdat <= {rdat[N_BITS-1:0], {N_BITS{1'b0}}};
                    end
                end

                default: begin
                    reg_rd <= '0;
                    reg_wr <= '0;
                    dout_valid <= '0;
                end

            endcase

        end
    end

    // Low-level SPI Rx and Tx logic.
    rtmc_spi_rxtx #(
        .N_BITS(N_BITS)
    )
    spi_rxtx(
        .*
    );

endmodule
