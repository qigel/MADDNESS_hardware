# MADDNESS_hardware
A Verilog implementation of MADDNESS algorythm https://github.com/dblalock/bolt

Can be used in 2 variants:
1. With internal memory (module MADDNESS) - contains all pre-calculated constants inside
2. With external memory (module MADDNESS_calc) - all pre-calculated constants must be set on input pins

Both options have these parameters:
1. layers - depth of classification trees
2. trees - number of classification trees
3. input_len - length of a row a of an input data matrix A
4. output_len - length of a row c of an output data matrix AB
5. bits - bit depth of module (same for values in input and output rows and all constants)

Module MADDNESS has these inputs:
1. in - input row a of input data matrix A
2. in_num - input number for internal memory
3. in_addr - adress where to write in_num
4. write - signal for write constant in internal memory
5. clk - clock signal

Structure of internal memory:
- [0:trees\*layers-1] - indicies for classification trees, indicies for same layer lay near
- [trees\*layers:trees\*layers+((2\*\*layers)-1)\*trees-1] - values for classification trees, value sets for same layer lay near without spaces
- [trees\*layers+((2\*\*layers)-1)\*trees:trees\*layers+((2\*\*layers)-1)\*trees+trees\*output_len\*(2\*\*layers)-1] - pre-calculated results (rows-prototypes, multiplied by matrix B), result rows for same tree lay near

Module MADDNESS_calc has these inputs:
1. in - input row a of the input data matrix A
2. indicies - indicies for classification trees, indicies for same layer go near
3. values - values for classification trees, each value set is padded with zeroes to 2**(layers-1) length, sets for same layer lay near
4. res - pre-calculated results, result rows for same tree lay near

Both modules have output out - output row c of the output matrix AB

!CAUTION! For better quality during an aggregation step module uses averaging operation, not addition. Remember it when you set constants.
