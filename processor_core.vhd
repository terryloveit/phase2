--Q1:Fix register file access hazard by doing reads in the second half of 
--the cycle and writes in the first half


--Q2: how to stall

--Q3: how to flush beq?


----------------------------------------------------------------------------------
-- Company: CUHK
-- Engineer: David & Terry 
-- 
-- Create Date:    11:10:31 16/04/2014 
-- Design Name:    PHASE2
-- Module Name:    
-- Project Name:   PHASE2
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity processor_core is
	port (
		clk		:	in std_logic;
		rst		:	in std_logic;
		run		:	in std_logic;
		instaddr:	out std_logic_vector(31 downto 0);
		inst	:	in std_logic_vector(31 downto 0);
		memwen	:	out std_logic;
		memaddr	:	out std_logic_vector(31 downto 0);
		memdw	:	out std_logic_vector(31 downto 0);
		memdr	:	in std_logic_vector(31 downto 0);
		fin		:	out std_logic;
		PCout	:	out std_logic_vector(31 downto 0);
		regaddr	:	in std_logic_vector(4 downto 0);
		regdout	:	out std_logic_vector(31 downto 0)
	);
end processor_core;

architecture arch_processor_core of processor_core is


component regtable 
	Port(
	clk		:	in std_logic;
	rst		:	in std_logic;
	raddrA	:	in std_logic_vector(4 downto 0);
	raddrB	:	in std_logic_vector(4 downto 0);
	wen		:	in std_logic;
	waddr	:	in std_logic_vector(4 downto 0);
	din		:	in std_logic_vector(31 downto 0);
	doutA	:	out std_logic_vector(31 downto 0);
	doutB	:	out std_logic_vector(31 downto 0);
	extaddr	:	in std_logic_vector(4 downto 0);
	extdout	:	out std_logic_vector(31 downto 0)
	);
	end component;
										

-- Add signals here





type instruction_type is (R_add,I_addi,R_sub,R_and, R_or,I_lw,I_sw,I_lui,R_slt,I_slti,R_sltu,I_sltiu,I_beq,J_j,invalid,Init);
signal instruction : instruction_type;

type PC_sourse_type is (P_branch,P_jump,P_pc_next);
signal PC_sourse : PC_sourse_type;


signal halt:std_logic;







								---- control signal------
	signal RegDst:std_logic;
	signal Jump:std_logic;
	signal Branch:std_logic;
	signal MemRead:std_logic;
	signal MemToReg:std_logic;
	signal ALUOp:std_logic_vector(1 downto 0);
	signal MemWrite:std_logic;
	signal ALUSrc:std_logic;
	signal RegWrite:std_logic;
	

		
					-- MEM signal------
		signal Store_byte:std_logic_vector(7 downto 0);	
		
	--------------------------- IF Stage--------------------------------
	
	signal PC_now: std_logic_vector(31 downto 0); 
	signal PC_in: std_logic_vector(31 downto 0); 

	---------------------------IF/ID register--------------------------------
	signal IF_ID_PC_D: std_logic_vector(31 downto 0); 
	signal IF_ID_PC_Q: std_logic_vector(31 downto 0); 

	signal IF_ID_INSTR_D: std_logic_vector(31 downto 0); 
	signal IF_ID_INSTR_Q: std_logic_vector(31 downto 0); 


   --------------------------- ID Stage--------------------------------
	signal ID_INSTR_31_26_D: std_logic_vector(31 downto 26); 
	signal ID_INSTR_31_26_Q: std_logic_vector(31 downto 26); 

	signal ID_INSTR_25_21_D: std_logic_vector(25 downto 21);--rs
	signal ID_INSTR_25_21_Q: std_logic_vector(25 downto 21);--rs

	signal ID_INSTR_20_16_D: std_logic_vector(20 downto 16);--rt
	signal ID_INSTR_20_16_Q: std_logic_vector(20 downto 16);--rt

	signal ID_INSTR_15_11_D: std_logic_vector(15 downto 11);--rt
	signal ID_INSTR_15_11_Q: std_logic_vector(15 downto 11);--rt

	signal ID_INSTR_15_0_D: std_logic_vector(15 downto 0);-- branch offset
	signal ID_INSTR_15_0_Q: std_logic_vector(15 downto 0);--branch offset

	signal ID_INSTR_5_0_D: std_logic_vector(5 downto 0); --funct
	signal ID_INSTR_5_0_Q: std_logic_vector(5 downto 0); --funct

	signal PC_next: std_logic_vector(31 downto 0); 

---------------------------ID/EX register--------------------------------
	signal ID_EX_WB_D: std_logic_vector(1 downto 0);
	signal ID_EX_WB_Q: std_logic_vector(1 downto 0);
	--(1) RegWrite
	--(0) MemtoReg

	signal ID_EX_M_D: std_logic_vector(2 downto 0);
	signal ID_EX_M_Q: std_logic_vector(2 downto 0);
	--(2) Branch
	--(1) MemRead
	--(0) MemWrite 

	signal ID_EX_EX_D: std_logic_vector(3 downto 0);
	signal ID_EX_EX_Q: std_logic_vector(3 downto 0);
	--(3) RegDst
	--(2) ALUop(1)
	--(1) ALUop(0)
	--(0) ALUSrc

	signal ID_EX_PC_D: std_logic_vector(31 downto 0);
	signal ID_EX_PC_Q: std_logic_vector(31 downto 0);

	signal ID_EX_Read_data_1_D: std_logic_vector(31 downto 0);
	signal ID_EX_Read_data_1_Q:std_logic_vector(31 downto 0);

	signal IF_ID_Read_data_1_Q: std_logic_vector(31 downto 0);
	signal IF_ID_Read_data_2_Q: std_logic_vector(31 downto 0);

	signal ID_EX_Read_data_2_D: std_logic_vector(31 downto 0);
	signal ID_EX_Read_data_2_Q: std_logic_vector(31 downto 0);

	signal ID_EX_INSTR_25_21_D: std_logic_vector(25 downto 21);
	signal ID_EX_INSTR_25_21_Q: std_logic_vector(25 downto 21);

	signal ID_EX_INSTR_20_16_D: std_logic_vector(20 downto 16);
	signal ID_EX_INSTR_20_16_Q: std_logic_vector(20 downto 16);

	signal ID_EX_INSTR_15_11_D: std_logic_vector(15 downto 11);
	signal ID_EX_INSTR_15_11_Q: std_logic_vector(15 downto 11);


	signal ID_EX_WB_Register_D: std_logic;

	signal ID_EX_instruction_D: instruction_type;
	signal ID_EX_instruction_Q: instruction_type;


--------------------------- EX Stage--------------------------------

							-- ALU signal------
		signal zero:std_logic;	
		signal calculate_zero_temp:std_logic;	
		signal ALU_muti: std_logic_vector(31 downto 0);

		signal ALU_input_1 : std_logic_vector(31 downto 0);
		signal ALU_input_2 : std_logic_vector(31 downto 0);

		signal ID_EX_SignExtension_D : std_logic_vector(31 downto 0);
		signal ID_EX_SignExtension_Q : std_logic_vector(31 downto 0);

		signal ID_EX_ZeroExtension_D : std_logic_vector(31 downto 0);
		signal ID_EX_ZeroExtension_Q : std_logic_vector(31 downto 0);

		signal ALU_control_output : std_logic_vector(3 downto 0);
		signal calculate_temp1:std_logic_vector(31 downto 0);	
		signal calculate_temp2:std_logic_vector(32 downto 0);	
		
	signal ForwardA: std_logic_vector(1 downto 0);
	signal ForwardB: std_logic_vector(1 downto 0);
	signal EX_WriteData: std_logic_vector(31 downto 0);
	signal SrcA, SrcB: std_logic_vector(31 downto 0);

--------------------------- EX/MEM register--------------------------------
	signal EX_MEM_instruction_D: instruction_type;
	signal EX_MEM_instruction_Q: instruction_type;


	signal EX_MEM_WB_D: std_logic_vector(1 downto 0);
	signal EX_MEM_WB_Q: std_logic_vector(1 downto 0);
	--(1) RegWrite
	--(0) MemtoReg

	signal EX_MEM_M_D: std_logic_vector(2 downto 0);
	signal EX_MEM_M_Q: std_logic_vector(2 downto 0);
	--(2) Branch
	--(1) MemRead
	--(0) MemWrite 


	signal EX_MEM_ALUOut_D: std_logic_vector(31 downto 0);
	signal EX_MEM_ALUOut_Q: std_logic_vector(31 downto 0);

	signal EX_MEM_Write_register_D: std_logic_vector(4 downto 0);
	signal EX_MEM_Write_register_Q: std_logic_vector(4 downto 0);
	


	signal EX_MEM_memaddr : std_logic_vector(31 downto 0);

	
---------------------------  MEM Stage--------------------------------
	signal EX_MEM_Zero: std_logic;
	signal PCsrc: std_logic;
	signal stall: std_logic;
	signal flush: std_logic;
	signal flush3times: std_logic;

	signal EX_MEM_writeData: std_logic_vector(31 downto 0);
	signal PC_branch: std_logic_vector(31 downto 0);
	signal PC_branch_MEM: std_logic_vector(31 downto 0);
			


--------------------------- MEM/WB register--------------------------------
	signal MEM_WB_instruction_D: instruction_type;
	signal MEM_WB_instruction_Q: instruction_type;

	signal MEM_WB_Write_register_D: std_logic_vector(4 downto 0);
	signal MEM_WB_Write_register_Q: std_logic_vector(4 downto 0);

	signal MEM_WB_WB_D: std_logic_vector(1 downto 0);	
	signal MEM_WB_WB_Q: std_logic_vector(1 downto 0);
	--(1) RegWrite
	--(0) MemtoReg


	signal RegWriteAddr: STD_LOGIC_VECTOR(4 downto 0);
	signal MEM_WB_readData_D: std_logic_vector(31 downto 0);
	signal MEM_WB_readData_Q: std_logic_vector(31 downto 0);

	signal MEM_WB_ALUOut_D: std_logic_vector(31 downto 0);
	signal MEM_WB_ALUOut_Q: std_logic_vector(31 downto 0);


--------------------------- WB Stage--------------------------------
	signal RegWriteData: std_logic_vector(31 downto 0);





					---- PC related internal data ------
	signal clk_enable :std_logic:='0';		
	signal PCclk :std_logic;		
	signal finished :std_logic:='0';	
			

	signal Sign_extend: std_logic_vector(31 downto 0);
								
				---- register related internal data ------
	signal Write_data:std_logic_vector(31 downto 0);


	
------------------------------- begin-------------------------------
begin
-- Processor Core Behaviour




--pay attention to the clk 

regtable1: regtable port map (clk,rst,IF_ID_INSTR_Q(25 downto 21),IF_ID_INSTR_Q(20 downto 16), RegWrite,RegWriteAddr,Write_data,ID_EX_Read_data_1_D,ID_EX_Read_data_2_D,regaddr,regdout);






process (clk, rst)
	begin
   if (rst='1') then clk_enable <= '0';
   elsif rising_edge(clk)  then		    
         if (run='1') then clk_enable <= '1'; 
         end if;
    end if;     
 end process;

	PCclk <= (clk) and (clk_enable) and (not finished);
	
 --------------------------IF Stage------------------------------
process (rst,PCclk)
		begin
		if (rst='1') then
			PC_now <="00000000000000000100000000000000"; 		
	   	  elsif rising_edge(PCclk) then
	   	  	if stall='1' or ( (clk_enable='1') and ( inst="00000000000000000000000000000000" ))then
		    PC_now <= PC_now;
		    else
		    PC_now <= PC_in;
		    end if;
		end if;		
	end process;
	
						 

	halt <= 
		'1' when ((MEM_WB_instruction_Q=I_lw or MEM_WB_instruction_Q=I_sw) and  EX_MEM_ALUOut_Q(1 downto 0) /= "00")
			or ((MEM_WB_instruction_Q=invalid and EX_MEM_instruction_Q=invalid and ID_EX_instruction_Q=invalid ) or not PC_in(1 downto 0) = "00") else 
		'0';

	process (clk, run)
	begin
		if (run = '1') then finished <= '0';	
		elsif rising_edge(clk)  then
		    finished <= (finished or halt);
		end if;
	end process;

	fin <= finished;


			---PC_update--
			PCout<=PC_now;
			instaddr<=PC_now;
			PC_next<=PC_now+"00000000000000000000000000000100";
--here		PC_branch<=Pc_Next+(SignExtension(29 downto 0)&"00");
	

			---PC source--
		
				

				   PC_in <= PC_branch when PCSrc = '1' else
			       		 (PC_now(31 downto 28) & IF_ID_INSTR_Q(25 downto 0 ) & "00")  when Jump='1' else
	             		  	Pc_Next ;


		


  
-----------------IF/ID register------------
 
	IF_ID_PC_D <= PC_next;
	IF_ID_INSTR_D <= inst;


				ID_INSTR_31_26_D <= IF_ID_INSTR_Q(31 downto 26);
				ID_INSTR_25_21_D <= IF_ID_INSTR_Q(25 downto 21);
				ID_INSTR_20_16_D <= IF_ID_INSTR_Q(20 downto 16);
				ID_INSTR_15_11_D <= IF_ID_INSTR_Q(15 downto 11);
				ID_INSTR_15_0_D <= IF_ID_INSTR_Q(15 downto 0);
				ID_INSTR_5_0_D <= IF_ID_INSTR_Q(5 downto 0);

	process (PCclk)
		begin
			if rising_edge(PCclk) then
			IF_ID_PC_Q <= IF_ID_PC_D;
			IF_ID_INSTR_Q<= IF_ID_INSTR_D;
		--	ID_EX_Read_data_1_D<=IF_ID_Read_data_1_Q;
		--	ID_EX_Read_data_2_D<=IF_ID_Read_data_2_Q;
			end if;
	end process;
 

 --------------------------ID Stage------------------------------

				
	

 	process(rst,IF_ID_INSTR_Q)
 	begin 
 	if(rst='1') then
	 	instruction<=Init;
	 	elsif (IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000100000") then
			instruction<= R_add;
		elsif (IF_ID_INSTR_Q(31 downto 26)="001000") then
			instruction<= I_addi;
		elsif (IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000100010") then
			instruction<= R_sub;
		elsif (IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000100100") then
			instruction<= R_and;
		elsif ( IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000100101") then
			instruction<= R_or;
			elsif ( IF_ID_INSTR_Q(31 downto 26)="100011") then
			instruction<= I_lw;
		elsif ( IF_ID_INSTR_Q(31 downto 26)="101011") then
			instruction<= I_sw;
		elsif (IF_ID_INSTR_Q(31 downto 26)="001111") then
			instruction<= I_lui;
			elsif (IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000101010") then
			instruction<= R_slt;
		elsif ( IF_ID_INSTR_Q(31 downto 26)="001010") then
			instruction<= I_slti;
		elsif (IF_ID_INSTR_Q(31 downto 26)="000000" and IF_ID_INSTR_Q(10 downto 0)="00000101011") then
			instruction<= R_sltu;
			elsif ( IF_ID_INSTR_Q(31 downto 26)="001011") then
			instruction<= I_sltiu;
		elsif ( IF_ID_INSTR_Q(31 downto 26)="000010" ) then
			instruction<= J_j;
		elsif ( IF_ID_INSTR_Q(31 downto 26)="000100") then
			instruction<= I_beq;
		else
			instruction<= invalid;
	end if;
end process;
	
			ID_EX_instruction_D<=instruction;
						 
						
	-----------------------------------------------------------					  
	---RegDst
	 ID_EX_EX_D(3) <= '1' when instruction=R_add or 
							instruction=R_sub or 
							instruction=R_and or 
							instruction=R_or or 
							instruction=R_slt or 
							instruction=R_sltu else
	          '0';
	---------------------------------------
	
	Jump<='1' when  instruction=J_j else
			'0' ;

	flush<=Jump;
--------------------------------------------------------------------
	--Branch 
	ID_EX_M_D(2)<='1' when  instruction=I_beq  else
				'0' ;
	
---------------------------------------------------------------
	--MemRead
	ID_EX_M_D(1)<='1' when instruction=I_lw else
				'0' ;
	
	---------------------------------------------------------
	---Q2 mem to reg sw
	--MemtoReg
	ID_EX_WB_D(0)	<='1' when instruction=I_lw  else
					'0' ;



	--------------------------------------------
	--ALUOp
	ID_EX_EX_D(2 downto 1) <= "10"  when instruction=R_add or 
							  instruction=R_sub or 
							  instruction=R_and or 
							  instruction=R_or or 
							  instruction=R_slt or 
							  instruction=R_sltu else

							 "01" when instruction=I_lw or 
							  instruction=I_sw else

							  "00" when instruction=I_addi or 
							  instruction=I_slti or
							  instruction=I_sltiu or
							  instruction=I_lui else 

								"11";
	----------------------------------------------------------
	--MemWrite
	ID_EX_M_D(0)<='1' when instruction=I_sw  else       
					'0' ;


	-----------------------------------------------------------
	--QQ		
		--ALUSrc
	ID_EX_EX_D(0)<='0'		when instruction=I_beq or  --read from register
							  instruction=R_add or 
							  instruction=R_sub or 
							  instruction=R_and or 
							  instruction=R_or or 
							  instruction=R_slt or 
							  instruction=R_sltu else     
							  
					'1' when instruction=I_addi or --comes from inst
							  instruction=I_slti or
							  instruction=I_lw or 
							  instruction=I_sw or 
							  instruction=I_sltiu or
							  instruction=I_lui;
			--	else null; 			  
					
	-----------------------------------------------------------		
	--		
	--RegWrite
		ID_EX_WB_D(1)	<='1' when instruction=I_lw or 
							  instruction=R_add or 
							  instruction=R_sub or 
							  instruction=R_and or 
							  instruction=R_or or 
							  instruction=R_slt or 
							  instruction=R_sltu or
								instruction=I_addi or 
							  instruction=I_lui or
								instruction=I_slti or
								instruction=I_sltiu	else     		
					'0';


		-----------------------------------------------------------
		
				
	ID_EX_SignExtension_D <= "1111111111111111" & IF_ID_INSTR_Q(15 downto 0) when IF_ID_INSTR_Q(15)='1' else 
					"0000000000000000" & IF_ID_INSTR_Q(15 downto 0);	
			
	ID_EX_ZeroExtension_D <="0000000000000000" & IF_ID_INSTR_Q(15 downto 0);						



	


				ID_EX_PC_D <= IF_ID_PC_Q; 


-------------------- ID/EX register  --------------------


process (PCclk)
		begin
			if rising_edge(PCclk) then
				ID_EX_PC_Q <= ID_EX_PC_D;  
				ID_EX_instruction_Q<=ID_EX_instruction_D;
				ID_EX_WB_Q <= ID_EX_WB_D;
				ID_EX_M_Q <= ID_EX_M_D;
				ID_EX_EX_Q <= ID_EX_EX_D;
				ID_EX_Read_data_1_Q <= ID_EX_Read_data_1_D;
				ID_EX_Read_data_2_Q <= ID_EX_Read_data_2_D;
				ID_EX_SignExtension_Q <= ID_EX_SignExtension_D;
				ID_EX_INSTR_25_21_Q<=ID_INSTR_25_21_D;
				ID_EX_INSTR_20_16_Q <= ID_INSTR_20_16_D;
				ID_EX_INSTR_15_11_Q <= ID_INSTR_15_11_D;
			end if;
	end process;

				EX_MEM_WB_D<=ID_EX_WB_Q;
				EX_MEM_M_D <= ID_EX_M_Q;
				RegDst<= ID_EX_EX_Q(3);
				ALUOp <= ID_EX_EX_Q(2 downto 1);
				ALUSrc <= ID_EX_EX_Q(0);


 --------------------------EX Stage------------------------------

ALU_control_output <=   "0110" when  ID_EX_instruction_Q=I_addi or
								ID_EX_instruction_Q=R_add or
								ID_EX_instruction_Q=I_lw or
								ID_EX_instruction_Q=I_sw else

				   "1110" when ID_EX_instruction_Q=I_beq or
								ID_EX_instruction_Q=R_sub else

				   "0000" when ID_EX_instruction_Q=R_and else

				   "0001" when ID_EX_instruction_Q=R_or else
						
				   "1111" when ID_EX_instruction_Q=R_slt or
								ID_EX_instruction_Q=I_slti or
								ID_EX_instruction_Q=R_sltu or
								ID_EX_instruction_Q=I_sltiu ;
					--else null;







EX_MEM_Write_register_D <= ID_EX_INSTR_20_16_Q when RegDst = '0' else --rd
					ID_EX_INSTR_15_11_Q; --rt




	
	ALU_input_2 <= ID_EX_SignExtension_Q when ALUSrc = '1' else 
			EX_WriteData;


	process(PCclk)
		begin 
		 if (PCclk='0') then 
		      case ForwardA is
		      when "00"=> ALU_input_1 <= ID_EX_Read_data_1_Q;
		      when "10"=> ALU_input_1 <= EX_MEM_ALUOut_Q;
		      when "01"=> ALU_input_1 <= RegWriteData;
		      when others=> ALU_input_1 <= "00000000000000000000000000000000";
		      end case;

		      case ForwardB is
		      when "00"=> EX_WriteData <= ID_EX_Read_data_2_Q;
		      when "10"=> EX_WriteData <= EX_MEM_ALUOut_Q;
		      when "01"=> EX_WriteData <= RegWriteData;
		      when others=> EX_WriteData <= "00000000000000000000000000000000";
		      end case;
		  end if;
		 end process;




			

    process (ALU_input_1, ALU_input_2, ID_EX_instruction_Q)
		begin
			   case ID_EX_instruction_Q is 
			      when I_addi =>
			       calculate_temp1 <= ALU_input_1 + ALU_input_2;

			       when  R_add=>
			       calculate_temp1 <= ALU_input_1 + ALU_input_2;

			      when R_or =>
			       calculate_temp1 <= ALU_input_1 or ALU_input_2;

			      when R_and =>
			          calculate_temp1 <= ALU_input_1 and ALU_input_2;

			      when I_lui =>
			         calculate_temp1 <=  ALU_input_2(15 downto 0) & "0000000000000000";

			      when others =>
			          calculate_temp1 <= ALU_input_1 - ALU_input_2;
			   end case;
	end process;
	
	calculate_temp2<=	('1'&ALU_input_1)-('0'& ALU_input_2);--unsiged difference

	EX_MEM_ALUOut_D<=calculate_temp1 when  (ID_EX_instruction_Q=R_add or ID_EX_instruction_Q=I_addi or ID_EX_instruction_Q=R_sub or ID_EX_instruction_Q=R_and or ID_EX_instruction_Q=R_or or ID_EX_instruction_Q=I_lw or ID_EX_instruction_Q=I_sw or ID_EX_instruction_Q=I_lui or ID_EX_instruction_Q=I_beq ) else
				  "0000000000000000000000000000000"& not(calculate_temp2(32)) when (ID_EX_instruction_Q=R_sltu or ID_EX_instruction_Q=I_sltiu )else 
				   "0000000000000000000000000000000"& calculate_temp1(31); 

			
	calculate_zero_temp<='1' when EX_MEM_ALUOut_D="00000000000000000000000000000000" else 
									'0';
									
	


	PC_branch_MEM<= ID_EX_PC_Q + (ID_EX_SignExtension_Q(29 downto 0) & "00"); 

	

-------------------------------------------------

 ----------------------------------- EX/MEM register-------------------------

 EX_MEM_instruction_D<=ID_EX_instruction_Q;
process(PCclk)
		begin
			if rising_edge(PCclk) then
				zero <= calculate_zero_temp;
				PC_branch<=	PC_branch_MEM;
				EX_MEM_instruction_Q<=EX_MEM_instruction_D;
				EX_MEM_WB_Q <= EX_MEM_WB_D;
				EX_MEM_M_Q <= EX_MEM_M_D;
				EX_MEM_ALUOut_Q <= EX_MEM_ALUOut_D;
				EX_MEM_writeData <= EX_WriteData;
				EX_MEM_Write_register_Q<=EX_MEM_Write_register_D;
				
			end if;
	end process;

	
  ----------------------------- MEM Stage  --------------------------------


				PCsrc <= Branch and zero;
				MemRead <= EX_MEM_M_Q(1);
				Branch <= EX_MEM_M_Q(2);

				flush3times<=Branch;

				MemWrite <= EX_MEM_M_Q(0);

	MEM_WB_WB_D <= EX_MEM_WB_Q;

	EX_MEM_memaddr<=(EX_MEM_ALUOut_Q(31 downto 2)&"00");--shiftleft

	memwen<=MemWrite;

	MEM_WB_readData_D <= memdr;

	memdw <= EX_MEM_writeData;
	memaddr<=EX_MEM_memaddr;

	--here
	MEM_WB_ALUOut_D<=EX_MEM_ALUOut_Q;
	--MEM_WB_ALUOut_D<=EX_MEM_writeData;

	MEM_WB_Write_register_D<=EX_MEM_Write_register_Q;

	MEM_WB_instruction_D<=EX_MEM_instruction_Q;
  ----------------------- MEM/WB register -------------
		process(PCclk)
		begin
			MEM_WB_instruction_Q<=MEM_WB_instruction_D;
			MEM_WB_WB_Q <= MEM_WB_WB_D;
			MEM_WB_readData_Q <= MEM_WB_readData_D;
			MEM_WB_ALUOut_Q <= MEM_WB_ALUOut_D;
			MEM_WB_Write_register_Q <= MEM_WB_Write_register_D;
		
	end process;

		----------------- WB stage------------------
	RegWrite <= MEM_WB_WB_Q(1);
	MemtoReg <= MEM_WB_WB_Q(0);
	

	RegWriteAddr <= MEM_WB_Write_register_Q;
	--RegWriteAddr <= EX_MEM_Write_register_D;

	RegWriteData<=MEM_WB_readData_Q when MemToReg = '1' else
					MEM_WB_ALUOut_Q;

	Write_data <= MEM_WB_readData_Q when MemToReg = '1' else
					MEM_WB_ALUOut_Q;


	---------------------------EX Forward Unit -----------
ForwardA(1) <= '1' when ((EX_MEM_WB_Q(1)='1' or Branch='1') and (EX_MEM_Write_register_Q /= "00000") and (EX_MEM_Write_register_Q = ID_EX_INSTR_25_21_Q)) else
			'0';

ForwardB(1) <= '1' when ((EX_MEM_WB_Q(1)='1' or Branch='1') and (EX_MEM_Write_register_Q /= "00000") and (EX_MEM_Write_register_Q = ID_EX_INSTR_20_16_Q)) else 
			'0';


				------------MEM Forward Unit-----------------
ForwardA(0) <= '1' when (RegWrite='1' and (MEM_WB_Write_register_Q /= 0) and (EX_MEM_Write_register_Q /= ID_EX_INSTR_25_21_Q) and (MEM_WB_Write_register_Q = ID_EX_INSTR_25_21_Q)) else
			'0';

ForwardB(0)<= '1' when (RegWrite='1' and (MEM_WB_Write_register_Q /= 0) and (EX_MEM_Write_register_Q /= ID_EX_INSTR_20_16_Q) and (MEM_WB_Write_register_Q = ID_EX_INSTR_20_16_Q)) else
			'0';




----------------------------------ID Hazard detection Unit-------------------


		stall<='1' when ( (ID_EX_M_D(1)='1') and ((ID_INSTR_20_16_D = IF_ID_INSTR_Q(20 downto 16)) or ( ID_INSTR_20_16_D = IF_ID_INSTR_Q(25 downto 21) )) ) else
				'0';

		







--if (IDcontrol.Branch
--and (EX/MEM.RegisterRd != 0)
--and (EX/MEM.RegisterRd = IF/ID.RegisterRs))
--		ForwardC = 1
--if (IDcontrol.Branch
--and (EX/MEM.RegisterRd != 0)
--and (EX/MEM.RegisterRd = IF/ID.RegisterRt))
--		ForwardD = 1


  ------------------------Bubble --------------------------
	--process(branch,Zero)
  --     begin
	--	   if branch = '1' and ReadData1 = ReadData2(or imm)
	--			PCSrc = change_one;
	--end process;
  ----------------------------------------------------------------------------------------


end arch_processor_core;
