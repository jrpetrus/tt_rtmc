/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

 // Motor Controller State machine + registers.

module rtmc_ctrl #(
    parameter ADDR_W = 8,
    parameter DATA_W = 16,
    parameter MC_W = 8,
    parameter MC_DEPTH = 16
)
(
    input  logic clk,
    input  logic rst_n,

    // Register bus.
    input  logic [ADDR_W-1:0] reg_addr,
    input  logic [DATA_W-1:0] reg_wdat,
    input  logic reg_wr,
    input  logic reg_rd,
    output logic [DATA_W-1:0] reg_rdat,
    output logic reg_ack,

    // GPIO.
    input  logic [3:0] gpi,
    output logic [3:0] gpo,

    // Stepper motors.
    output logic [MC_W-1:0] mc,
    output logic [MC_W-1:0] mc_oe
);
    // Register offsets.
    localparam ID_REG = 0;
    localparam GPIO_REG = 1;
    localparam STEP_CTRL_REG = 2;
    localparam STEP_STAT_REG = 3;
    localparam STEP_DELAY_0_REG = 4;
    localparam STEP_DELAY_1_REG = 5;
    localparam STEP_COUNT_0_REG = 6;
    localparam STEP_COUNT_1_REG = 7;
    localparam DELAY_COUNT_0_REG = 8;
    localparam DELAY_COUNT_1_REG = 9;

    localparam TABLE_ADDR_BIT = 4;
    typedef logic [TABLE_ADDR_BIT-1:0] register_address_t;
    typedef logic [$clog2(MC_DEPTH)-1:0] table_address_t;

    // ID register contents.
    localparam logic [7:0] VERSION = 'h01;
    localparam logic [7:0] IDCODE = 'h42;  // "M" in UTF-8

    // Addressing
    register_address_t register_address;
    table_address_t table_address;

    // Cycle counter.
    logic [2*DATA_W-1:0] step_delay;
    logic [2*DATA_W-1:0] delay_count, next_delay_count;
    logic step_delay_hit;
    logic delay_count_clr;

    // Step Counter.
    logic signed [2*DATA_W-1:0] step_count, next_step_count;
    logic step_count_clr;
    
    // Motor Control Table indexing.
    logic [MC_W-1:0] step_table[0:MC_DEPTH-1];
    table_address_t table_idx, next_table_idx;
    table_address_t table_last;
    logic signed [$clog2(MC_DEPTH):0] step_size;
    logic signed [$clog2(MC_DEPTH):0] table_idx_p_step_size;
    logic table_idx_p_step_size_ltz;
    logic do_step;
    logic do_run; 

    // Motor Control SM
    enum logic[3:0] {
        IDLE = 'd0,
        RUN = 'd1
    } state, next_state;

    // Register access.
    assign register_address = reg_addr[$left(register_address):0];
    assign table_address = reg_addr[$left(table_address):0];

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            reg_ack <= '0;
            gpo <= '0;
            step_delay <= '0;
            table_last <= '0;
            step_size <= '0;
            do_step <= '0;
            do_run <= '0;
            step_count_clr <= '0;
            delay_count_clr <= '0;
            mc_oe <= '0;
        end
        else begin
            // single pulse signals
            step_count_clr <= '0;
            delay_count_clr <= '0;
            do_step <= '0;

            // Register bus ack.
            if(reg_wr || reg_rd) 
                reg_ack <= ~reg_ack;
            else
                reg_ack <= '0;

            if(reg_wr) begin
                if(reg_addr[TABLE_ADDR_BIT]) begin
                    step_table[table_address] <= reg_wdat[MC_W-1:0];
                end
                else begin
                    case(register_address)
                        GPIO_REG: begin
                            {mc_oe, gpo} <= reg_wdat[$bits(mc_oe)+$bits(gpo)+$bits(gpi)-1:$bits(gpi)];
                        end
                        STEP_CTRL_REG: begin
                            do_run <= reg_wdat[15];
                            do_step <= reg_wdat[14] & ~reg_wdat[15] & ~do_run;
                            {table_last, step_size} <= reg_wdat[$bits(table_last)+$bits(step_size)-1:0];
                        end                        
                        STEP_DELAY_0_REG: begin
                            step_delay[2*DATA_W-1:DATA_W] <= reg_wdat;
                        end
                        STEP_DELAY_1_REG: begin
                            step_delay[DATA_W-1:0] <= reg_wdat;
                        end
                        STEP_COUNT_0_REG: begin
                            step_count_clr <= '1;
                        end
                        STEP_COUNT_1_REG: begin
                            step_count_clr <= '1;
                        end
                        DELAY_COUNT_0_REG: begin
                            delay_count_clr <= '1;
                        end
                        DELAY_COUNT_1_REG: begin
                            delay_count_clr <= '1;
                        end
                        default: begin
                            // pass
                        end
                    endcase
                end
            end

            if(reg_rd) begin
                reg_rdat <= '0;
                if(reg_addr[TABLE_ADDR_BIT]) begin
                    reg_rdat[MC_W-1:0] <= step_table[table_address];
                end
                else begin
                    case(register_address)
                        ID_REG: begin
                            reg_rdat <= {VERSION, IDCODE};
                        end
                        GPIO_REG: begin
                            reg_rdat[$bits(mc_oe)+$bits(gpo)+$bits(gpi)-1:0] <= {mc_oe, gpo, gpi};
                            reg_rdat[$left(gpi):0] <= gpi;
                        end
                        STEP_CTRL_REG: begin
                            reg_rdat[15] <= do_run;
                            reg_rdat[14] <= do_step;
                            reg_rdat[$bits(table_last)+$bits(step_size)-1:0] <= {table_last, step_size};
                        end
                        STEP_STAT_REG: begin
                            reg_rdat[$bits(state)+$bits(table_idx)-1:0] <= {state, table_idx};
                        end
                        STEP_DELAY_0_REG: begin
                            reg_rdat <= step_delay[2*DATA_W-1:DATA_W];
                        end
                        STEP_DELAY_1_REG: begin
                            reg_rdat <= step_delay[DATA_W-1:0];
                        end
                        STEP_COUNT_0_REG: begin
                            reg_rdat <= step_count[2*DATA_W-1:DATA_W];
                        end
                        STEP_COUNT_1_REG: begin
                            reg_rdat <= step_count[DATA_W-1:0];
                        end
                        DELAY_COUNT_0_REG: begin
                            reg_rdat <= delay_count[2*DATA_W-1:DATA_W];
                        end
                        DELAY_COUNT_1_REG: begin
                            reg_rdat <= delay_count[DATA_W-1:0];
                        end
                        default: begin
                            // error, unrecognized address
                            reg_rdat <= 'hEEEE; 
                        end
                    endcase
                end
            end
        end 
    end

    // Registered state.
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Next State logic.
    always_comb begin
        next_state = state;
        case(state)
            IDLE: begin
                if(do_run)
                    next_state = RUN;
            end
            RUN: begin
                if(do_run)
                    next_state = RUN;
                else
                    next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Cycle down counter.
    // Less logic to always compare to zero.
    // No hazard of missing step_delay if it changes to a 
    // lesser value during RUN.
    // Only active during RUN state.
    // Only clearable when not in RUN state.
    always_comb begin
        if(state == RUN) begin
            step_delay_hit = ~|delay_count;
            next_delay_count = 
                step_delay_hit ? step_delay : delay_count - 1'b1;
        end
        else begin
            step_delay_hit = '0;
            next_delay_count = delay_count_clr ? '0 : delay_count;
        end
    end

    // Step Counter.
    // Tracks the total steps in either + or - direction.
    // This is a SIGNED value that gives the user an indication
    // of position if controlling something that moves.
    always_comb begin
        next_step_count = step_count;
        if(step_count_clr)
            next_step_count = '0;
        else if(step_delay_hit) 
            next_step_count =
                step_count + {{$bits(step_count)-$bits(step_size){step_size[$left(step_size)]}}, step_size};
    end

    // Next table_idx logic.
    // step_size: table_idx will increment by $signed(step_size).
    // step_last: high limit of the table_idx. 0 is implied low limit.
    // Range is always 0:table_last-1.
    assign table_idx_p_step_size = table_idx + step_size;
    assign table_idx_p_step_size_ltz = table_idx_p_step_size[$left(table_idx_p_step_size)];

    always_comb begin
        next_table_idx = table_idx;
    
        if(do_step || step_delay_hit) begin
            if(table_idx_p_step_size_ltz)
                // table_idx can't be negative.
                next_table_idx = table_last;
            else if(table_idx_p_step_size >= {1'b0, table_last})
                // table_idx can't exceed table_last.
                next_table_idx = '0;
            else
                next_table_idx = table_idx_p_step_size[$left(next_table_idx):0];
        end
    end

    // Counter and index registers.
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            delay_count <= '0;
            step_count <= '0;
            table_idx <= '0;
        end
        else begin
            delay_count <= next_delay_count;
            step_count <= next_step_count;
            table_idx <= next_table_idx;
        end
    end

    // Motor state output.
    always_comb begin
        mc = step_table[table_idx];
    end

endmodule
