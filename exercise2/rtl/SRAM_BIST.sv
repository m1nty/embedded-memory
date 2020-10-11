/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

module SRAM_BIST (
	input logic Clock,
	input logic Resetn,
	input logic BIST_start,
	
	output logic [17:0] BIST_address,
	output logic [15:0] BIST_write_data,
	output logic BIST_we_n,
	input logic [15:0] BIST_read_data,
	
	output logic BIST_finish,
	output logic BIST_mismatch
);

enum logic [2:0] {
	S_IDLE,
	S_DELAY_1,
	S_DELAY_2,
	S_WRITE_CYCLE,
	S_READ_CYCLE,
	S_DELAY_3,
	S_DELAY_4
} BIST_state;

logic BIST_start_buf;
logic [15:0] BIST_expected_data;

logic [1:0]read_increment;
logic write_increment;
logic comparison;
logic [1:0]limit;
logic mode;
logic [15:0] data;
// write the 16 least significant bits of the address bus in each memory location
// 
// NOTE: this particular BACKGROUND pattern is specific to this BIST implementation
assign BIST_write_data[15:0] = BIST_address[15:0];

// based on the way how this particular BIST engine is implemented,
// the BIST expected data can be computed on-the-fly by
// decrementing the 16 least significant bits of the address 
//
// NOTE: the expected data must change if the memory is traversed in a different way
always_comb begin
	if(mode == 1'b0)
		data = BIST_address[15:0] - 16'd2;
	else
		data = BIST_address[15:0] + 16'd2;
end

assign BIST_expected_data[15:0] = data;

always_ff @ (posedge Clock or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		BIST_state <= S_IDLE;
		BIST_mismatch <= 1'b0;
		BIST_finish <= 1'b0;
		BIST_address <= 18'd0;
		BIST_we_n <= 1'b1;		
		BIST_start_buf <= 1'b0;
		read_increment <= 1'b0;
		write_increment <= 1'b0;
		comparison <= -16'd2;
		mode <= 1'b0;
		limit <= 2'b0;
	end else begin
		BIST_start_buf <= BIST_start;
		
		case (BIST_state)
		S_IDLE: begin
			if (BIST_start & ~BIST_start_buf) begin
				// start the BIST engine
				BIST_address <= 18'd0;
				BIST_we_n <= 1'b0; // initiate first WRITE
				BIST_mismatch <= 1'b0;
				BIST_finish <= 1'b0;
				BIST_state <= S_WRITE_CYCLE;
			end else begin
				BIST_address <= 18'd0;
				BIST_we_n <= 1'b1;
				BIST_finish <= 1'b1;				
			end
		end
		// a couple of delay states to initiate the first WRITE and first READ
		S_DELAY_1: begin
			if(mode == 1'b0)
				BIST_address <= BIST_address + 1'b1;
			else
				BIST_address <= BIST_address - 1'b1;
			BIST_state <= S_DELAY_2;
		end
		S_DELAY_2: begin
			if(mode == 1'b0)
				BIST_address <= BIST_address + 1'b1;
			else
				BIST_address <= BIST_address - 1'b1;
				
			BIST_state <= S_READ_CYCLE;
		end
		S_WRITE_CYCLE: begin
			if(mode == 1'b0)
				BIST_address <= BIST_address + 1'b1;
			else 
				BIST_address <= BIST_address - 1'b1;
			if(BIST_address == 18'h1FFFF + write_increment) begin
				BIST_we_n <= 1'b1;
				BIST_state <= S_DELAY_1;
				if(mode == 1'b0) begin
					BIST_address <= 18'd0;
				end else begin
					BIST_address <= 18'h3FFFF;
				end
			end
		end
		S_READ_CYCLE: begin
			// complete the READ initiated two clock cycles earlier and perform comparison
			
			if (BIST_read_data != BIST_expected_data) 
				BIST_mismatch <= 1'b1;
			
			
			if(mode == 1'b0)
				BIST_address <= BIST_address + 1'b1;
			else 
				BIST_address <= BIST_address - 1'b1;
			if(BIST_address == 18'h1FFFF + read_increment) begin
				// delay for checking the last address
				if(mode == 1'b1) begin
					BIST_state <= S_IDLE;
					BIST_finish <= 1'b1;	
					read_increment <= 1'b0;
					comparison <= -16'd2;	
					mode <= 1'b0;
				end else
					BIST_state <= S_DELAY_3;
			end
		end
		S_DELAY_3: begin
			//comparison must be done
			if (BIST_read_data != BIST_expected_data) 
				BIST_mismatch <= 1'b1;
			if(mode == 1'b0)
				BIST_address <= BIST_address + 1'b1;
			else 
				BIST_address <= BIST_address - 1'b1;
			BIST_state <= S_DELAY_4;
		end
		S_DELAY_4: begin
			// check for data mismatch
			//comparison must be done
			
			if (BIST_read_data != BIST_expected_data) 
				BIST_mismatch <= 1'b1;
			
			// finish the whole SRAM
			if(mode == 1'b1) begin
				BIST_state <= S_IDLE;
				BIST_finish <= 1'b1;	
				read_increment <= 1'b0;
				write_increment <= 1'b1;
				comparison <= -16'd2;	
				mode <= 1'b0;
				
			end else begin
				BIST_state <= S_WRITE_CYCLE;
				BIST_address <= 18'h3FFFF;
				read_increment <= 2'd3;
				write_increment <= 1'b1;
				BIST_we_n <= 1'b0;
				comparison <= 16'd2;
				mode <= 1'b1;
				
			end
		end
		default: BIST_state <= S_IDLE;
		endcase
	end
end

endmodule
