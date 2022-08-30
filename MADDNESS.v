module MADDNESS #(parameter 
		layers = 4,
		trees = 4,
		input_len = 27,
		output_len = 8,
		bits = 8)
	(in, clk, out, in_num, in_addr, write);
	input [bits*input_len - 1:0] in;
	input clk;
	output [bits*output_len - 1:0] out;
	
	function integer clog2 (input integer n);
	begin
		n = n - 1;
		for(clog2 = 0; n > 0; clog2 = clog2 + 1)
			n = n >> 1;
	end
	endfunction
	
	
	localparam memsize = layers * trees + ((2 ** layers) - 1) * trees + trees * output_len * (2 ** layers);
	
	localparam addr_len = clog2(memsize);
	
	input [bits-1:0] in_num;
	input [addr_len-1:0] in_addr;
	input write;
	
	wire unsigned [layers-1:0][trees-1:0][bits-1:0] sep_indicies;
	wire unsigned [layers-1:0][trees-1:0][2**(layers-1)-1:0][bits-1:0] sep_values;
	wire unsigned [trees-1:0][2**layers-1:0][output_len-1:0][bits-1:0] precalc_res;
	
	wire unsigned [memsize-1:0][bits-1:0] membus;
	
	genvar cnt, cnt2;
	
	mem #(.bits(bits), .mem_size(memsize)) main_mem (.in_num(in_num), .in_addr(in_addr), .clk(clk), .out(membus), .write_en(write));
	
	assign sep_indicies = membus[layers*trees-1:0];
	generate
		for(cnt = 0; cnt < layers; cnt = cnt + 1) begin : memval
			for(cnt2 = 0; cnt2 < trees; cnt2 = cnt2 + 1) begin : memtr
				assign sep_values[cnt][cnt2][2**cnt-1:0] = membus[layers*trees + (2**(cnt)-1) * trees + (cnt2 + 1) * 2**cnt - 1:layers*trees + (2**(cnt)-1) * trees + cnt2 * 2**cnt];
				if(cnt < layers-1)
					assign sep_values[cnt][cnt2][2**(layers-1)-1:2**cnt] = 0;
			end
		end
	endgenerate
	assign precalc_res[trees - 1:0] = membus[memsize-1:layers * trees + ((2 ** layers) - 1) * trees];
	
	MADDNESS_calc #(.layers(layers), .trees(trees), .input_len(input_len), .output_len(output_len), .bits(bits))
		M (.in(in), .clk(clk), .out(out), .indicies(sep_indicies), .values(sep_values), .res(precalc_res));
	
endmodule

module mem #(parameter
	bits = 8,
	mem_size = 2108)
	(in_num, in_addr, clk, out, write_en);
	
	function integer clog2 (input integer n);
	begin
		n = n - 1;
		for(clog2 = 0; n > 0; clog2 = clog2 + 1)
			n = n >> 1;
	end
	endfunction
	
	localparam addr_len = clog2(mem_size);
	input [bits-1:0] in_num;
	input [addr_len-1:0] in_addr;
	input clk;
	input write_en;
	output [mem_size*bits-1:0] out;
	reg [mem_size-1:0][bits-1:0] memory;
	assign out = memory;
	
	always @(posedge clk)
		if(write_en)
			memory[in_addr] = in_num;
endmodule

module fork_mem #(parameter
	str_len = 16,
	bits = 8)
	(in_str, out_str, clk);
	input [bits*str_len - 1:0] in_str;
	input clk;
	output reg [bits*str_len - 1:0] out_str;
	always @(posedge clk)
		out_str = in_str;
endmodule

module fork_choice #(parameter
	str_len = 16,
	bits = 8)
	(in_str, sep_ind, out_val);
	input [bits*str_len - 1:0] in_str;
	input [bits-1:0] sep_ind;
	output [bits-1:0] out_val;
	wire [str_len-1:0][bits-1:0] str;
	assign str = in_str;
	assign out_val = str[sep_ind];
endmodule

module tree_fork #(parameter
	bits = 8,
	layer = 3,
	layers = 4,
	str_len = 16) 
	(in_str, sep_ind, in_class, out_class, clk, sep_values);
	input [layers - 1:0] in_class;
	input clk;
	input [bits*str_len - 1:0] in_str;
	input [bits-1:0] sep_ind;
	output [layers - 1:0] out_class;
	input [bits * 2**layer - 1:0] sep_values;
	wire [bits - 1:0] val;
	wire [2**layer - 1:0][bits - 1:0] sep_values_sep;
	fork_choice #(.str_len(str_len), .bits(bits)) c(in_str, sep_ind, val);
	assign sep_values_sep = sep_values;
	reg [layers - 1:0] classificator;
	integer cnt;
	assign out_class = classificator;
	always @(posedge clk)
	begin
		classificator = in_class;
		if(val < sep_values_sep[classificator])
			classificator[layer] = 1'b0;
		else
			classificator[layer] = 1'b1;
	end
endmodule

module sum_init #(parameter
	output_len = 32,
	trees = 4,
	bits = 8,
	layers = 4)
		(in_class1, in_class2, out_str, clk, precalc_res);
	input [layers - 1:0] in_class1;
	input [layers - 1:0] in_class2;
	input clk;
	output [bits*output_len - 1:0] out_str;
	input [2 * 2**layers * output_len * bits - 1:0] precalc_res;
	wire [1:0][2**layers-1:0][output_len-1:0][bits-1:0] precalc_res_sep;
	assign precalc_res_sep = precalc_res;
	reg [output_len - 1:0][bits- 1:0] str;
	integer cnt;
	assign out_str = str;
	always @(posedge clk)
	begin
		for(cnt = 0; cnt < output_len; cnt = cnt + 1)
			str[cnt] = (precalc_res_sep[0][in_class1][cnt] + precalc_res_sep[1][in_class2][cnt] + 1) >>> 1;
	end
endmodule

module sum_step #(parameter
	output_len = 32,
	trees = 4,
	bits = 8)
	(in_str1, in_str2, out_str, clk);
	input [bits*output_len - 1:0] in_str1;
	input [bits*output_len - 1:0] in_str2;
	input clk;
	output [bits*output_len - 1:0] out_str;
	reg [output_len - 1:0][bits - 1:0] str;
	wire [output_len - 1:0][bits - 1:0] str1;
	wire [output_len - 1:0][bits - 1:0] str2;
	assign str1 = in_str1;
	assign str2 = in_str2;
	assign out_str = str;
	integer cnt;
	always @(posedge clk)
	begin
		for(cnt = 0; cnt < output_len; cnt = cnt + 1)
			str[cnt] = (str1[cnt] + str2[cnt] + 1) >>> 1;
	end
endmodule

module MADDNESS_calc #(parameter 
		layers = 4,
		trees = 4,
		input_len = 27,
		output_len = 8,
		bits = 8)
	(in, clk, out, indicies, values, res);
	input [bits*input_len - 1:0] in;
	input clk;
	output [bits*output_len - 1:0] out;
	input [layers*trees*bits-1:0] indicies;
	input [layers*trees*(2**(layers-1))*bits-1:0] values;
	input [trees*(2**layers)*output_len*bits-1:0] res;
	wire unsigned [layers-1:0][trees-1:0][bits-1:0] sep_indicies;
	wire unsigned [layers-1:0][trees-1:0][2**(layers-1)-1:0][bits-1:0] sep_values;
	wire unsigned [trees:0][2**layers-1:0][output_len-1:0][bits-1:0] precalc_res;
	assign sep_indicies = indicies;
	assign sep_values = values;
	assign precalc_res[trees-1:0] = res;
	assign precalc_res[trees] = 0;
	
	function integer clog2 (input integer n);
	begin
		n = n - 1;
		for(clog2 = 0; n > 0; clog2 = clog2 + 1)
			n = n >> 1;
	end
	endfunction
	
	function integer progression(input integer n, integer k);
	begin
		for(progression = n; k > 0; k = k - 1) begin
			progression = progression + 1;
			progression = progression >> 1;
		end
	end
	endfunction
	
	localparam out_lvls = clog2(trees);
	
	wire unsigned [layers-1:0][input_len-1:0][bits-1:0] input_row;
	wire unsigned [layers:0][trees:0][layers-1:0] classificator;
	
	genvar cnt, cnt2;
	
	wire unsigned [out_lvls-1:0][(trees+1)>>1:0][output_len-1:0][bits-1:0] output_row;
	assign input_row[0] = in;
	assign out = output_row[out_lvls-1][0];
	assign classificator[0] = 0;
	assign classificator[layers][trees] = 0;
	generate
		for(cnt = 0; cnt < layers; cnt = cnt + 1) begin : cls
			if(cnt < layers - 1)
				fork_mem #(.str_len(input_len), .bits(bits))
					m (.in_str(input_row[cnt]), .out_str(input_row[cnt+1]), .clk(clk));
			for(cnt2 = 0; cnt2 < trees; cnt2 = cnt2 + 1) begin : trs
				tree_fork #(.bits(bits), .layer(cnt), .layers(layers), .str_len(input_len))
					f (.in_str(input_row[cnt]), .sep_ind(sep_indicies[cnt][cnt2]), .in_class(classificator[cnt][cnt2]), .out_class(classificator[cnt+1][cnt2]), .clk(clk), .sep_values(sep_values[cnt][cnt2][2**cnt-1:0]));
			end
		end
	endgenerate
	generate
		for(cnt = 0; cnt < trees; cnt = cnt + 2) begin : smint
			sum_init #(.output_len(output_len), .trees(trees), .bits(bits), .layers(layers))
				s (.in_class1(classificator[layers][cnt]), .in_class2(classificator[layers][cnt+1]), .out_str(output_row[0][cnt>>1]), .clk(clk), .precalc_res(precalc_res[cnt+1:cnt]));
		end
	endgenerate
	generate
		for(cnt = 0; cnt < out_lvls - 1; cnt = cnt + 1) begin : smlvl
			for(cnt2 = 0; cnt2 < progression(trees, cnt + 1); cnt2 = cnt2 + 2) begin : smstp
				sum_step #(.output_len(output_len), .trees(trees), .bits(bits))
					s (.in_str1(output_row[cnt][cnt2]), .in_str2(output_row[cnt][cnt2+1]), .out_str(output_row[cnt+1][cnt2>>1]), .clk(clk));
			end
		end
	endgenerate
endmodule
	