library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity DSP_LHRomMap is
	generic (
		USE_DSPn	: in std_logic := '0'
	);
	port(
		mclk			: in std_logic;
		rst_n			: in std_logic;
		enable		: in std_logic := '1';

		ca   			: in std_logic_vector(23 downto 0);
		di				: in std_logic_vector(7 downto 0);
		do				: out std_logic_vector(7 downto 0);
		cpurd_n		: in std_logic;
		cpuwr_n		: in std_logic;
		
		pa				: in std_logic_vector(7 downto 0);
		pard_n		: in std_logic;
		pawr_n		: in std_logic;
		
		romsel_n		: in std_logic;
		ramsel_n		: in std_logic;
		
		sysclkf_ce	: in std_logic;
		sysclkr_ce	: in std_logic;
		refresh		: in std_logic;
		
		irq_n			: out std_logic;

		rom_addr		: out std_logic_vector(23 downto 0);
		rom_q			: in  std_logic_vector(15 downto 0);
		rom_ce_n		: out std_logic;
		rom_oe_n		: out std_logic;
		rom_word		: out std_logic;
		
		bsram_addr	: out std_logic_vector(19 downto 0);
		bsram_d		: out std_logic_vector(7 downto 0);
		bsram_q		: in  std_logic_vector(7 downto 0);
		bsram_ce_n	: out std_logic;
		bsram_oe_n	: out std_logic;
		bsram_we_n	: out std_logic;

		map_active  : out std_logic;
		map_ctrl		: in std_logic_vector(7 downto 0);
		rom_mask		: in std_logic_vector(23 downto 0);
		bsram_mask	: in std_logic_vector(23 downto 0);
		
		ext_rtc		: in std_logic_vector(64 downto 0);
		
		brk_out		: out std_logic;
		dbg_reg		: in std_logic_vector(7 downto 0) := (others => '0');
		dbg_dat_in	: in std_logic_vector(7 downto 0) := (others => '0');
		dbg_dat_out	: out std_logic_vector(7 downto 0);
		dbg_dat_wr	: in std_logic := '0'
	);
end DSP_LHRomMap;

architecture rtl of DSP_LHRomMap is

	signal CART_ADDR 		: std_logic_vector(23 downto 0);
	signal ROM_SEL 		: std_logic;
	signal BRAM_ADDR 		: std_logic_vector(19 downto 0);
	signal BSRAM_SEL 		: std_logic;
	signal DP_SEL    		: std_logic;
	
	signal DSP_SEL	  		: std_logic;
	signal DSP_DO    		: std_logic_vector(7 downto 0);
	signal DSP_A0	  		: std_logic;
	signal DSP_CS_N  		: std_logic;
	signal DSP_CE	  		: std_logic;
	
	signal OBC1_SEL		: std_logic;
	signal OBC1_SRAM_A 	: std_logic_vector(12 downto 0);
	signal OBC1_SRAM_DO 	: std_logic_vector(7 downto 0);
	
	signal SRTC_DO 		: std_logic_vector(7 downto 0);
	signal SRTC_SEL		: std_logic;
	
	signal OPENBUS   		: std_logic_vector(7 downto 0);

	signal MAP_DSP_SEL 	: std_logic;
	signal MAP_OBC1_SEL 	: std_logic;
	signal DSP_CLK	  		: integer;
	signal ROM_RD	  		: std_logic;
		
begin
	
	MAP_DSP_SEL <= not MAP_CTRL(6) and (MAP_CTRL(7) or not (MAP_CTRL(5) or MAP_CTRL(4)));	--8..B
	MAP_OBC1_SEL <= MAP_CTRL(7) and MAP_CTRL(6) and not MAP_CTRL(5) and not MAP_CTRL(4);	--C
	MAP_ACTIVE <= MAP_DSP_SEL or MAP_OBC1_SEL;
	
	CEGen : entity work.CEGen
	port map(
		CLK     => MCLK,
		RST_N   => RST_N,
		IN_CLK  => 2147727,
		OUT_CLK => DSP_CLK,
		CE      => DSP_CE
	);
	
	DSP_CLK <= 760000 when MAP_CTRL(3) = '0' else 1000000;

	process( CA, MAP_CTRL, ROMSEL_N, RAMSEL_N, BSRAM_MASK, ROM_MASK )
	begin
		DP_SEL <= '0';
		DSP_SEL <= '0';
		OBC1_SEL <= '0';
		BSRAM_SEL <= '0';
		if ROM_MASK(23) = '0' then
			case MAP_CTRL(2 downto 0) is
				when "000" =>							-- LoROM/ExLoROM
					CART_ADDR <= '0' & not CA(23) & CA(22 downto 16) & CA(14 downto 0);
					BRAM_ADDR <= CA(20 downto 16) & CA(14 downto 0);
					if MAP_CTRL(3) = '0' then
						if CA(22 downto 20) = "111" and ROMSEL_N = '0' and BSRAM_MASK(10) = '1' then
							if ROM_MASK(20) = '1' or BSRAM_MASK(15) = '1' or MAP_CTRL(7) = '1' then
								BSRAM_SEL <= not CA(15);
							else
								BRAM_ADDR <= CA(19 downto 0);
								BSRAM_SEL <= '1';
							end if;
						end if;
						if (CA(22 downto 21) = "01" and CA(15) = '1' and ROM_MASK(20) = '0') or		--20-3F/A0-BF:8000-FFFF
							(CA(22 downto 20) = "110" and CA(15) = '0' and ROM_MASK(20) = '1') then	--60-6F/E0-EF:0000-7FFF
							DSP_SEL <= MAP_CTRL(7) and not MAP_CTRL(6);
						end if;
						DSP_A0 <= CA(14);
						if CA(22) = '0' and CA(15 downto 13) = "011" then									--00-3F/80-BF:6000-7FFF
							OBC1_SEL <= MAP_CTRL(7) and MAP_CTRL(6);
						end if;
					else
						if CA(22 downto 19) = "1101" and ROMSEL_N = '0' then 								--68-6F/E8-EF:0000-0FFF
							DP_SEL <= not CA(11);
							BSRAM_SEL <= CA(11);
						end if;

						if CA(22 downto 19) = "1100" then														--60-67/E0-E7:0000-0001
							DSP_SEL <= MAP_CTRL(7) and not MAP_CTRL(6);
						end if;
						DSP_A0 <= CA(0);
					end if;
				when "001" =>							-- HiROM
					CART_ADDR <= "00" & CA(21 downto 0);
					BRAM_ADDR <= "00" & CA(20 downto 16) & CA(12 downto 0);
					if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
						BSRAM_SEL <= '1';
					end if;
					if CA(22 downto 21) = "00" and CA(15 downto 13) = "011" then						--00-1F/80-9f:6000-7FFF
						DSP_SEL <= MAP_CTRL(7) and not MAP_CTRL(6);
					end if;
					DSP_A0 <= CA(12);
				when "101"|"010" =>					-- ExHiROM
					CART_ADDR <= "0" & (not CA(23)) & CA(21 downto 0);
					BRAM_ADDR <= "0" & CA(21 downto 16) & CA(12 downto 0);
					if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
						BSRAM_SEL <= '1';
					end if;
					DSP_SEL <= '0';
					DSP_A0 <= '1';
				when others =>
					CART_ADDR <= "0" & (not CA(23) and not MAP_CTRL(7)) & CA(21 downto 0);
					BRAM_ADDR <= CA(19 downto 0);
					BSRAM_SEL <= '0';
					DSP_SEL <= '0';
					DSP_A0 <= '1';
			end case;
		else												--96Mbit 
			if CA(15) = '0' then
				CART_ADDR <= "10" & CA(23) & CA(21 downto 16) & CA(14 downto 0);
			else
				CART_ADDR <= "0" & CA(23 downto 16) & CA(14 downto 0);
			end if;
			BRAM_ADDR <= "00" & CA(20 downto 16) & CA(12 downto 0);
			if CA(22 downto 21) = "01" and CA(15 downto 13) = "011" and BSRAM_MASK(10) = '1' then
				BSRAM_SEL <= '1';
			end if;
			DSP_SEL <= '0';
			DSP_A0 <= '1';
		end if;
	end process;
	
	SRTC_SEL <= '1' when CA(22) = '0' and CA(15 downto 1) = x"280"&"000" else '0';
	ROM_SEL <= not ROMSEL_N and not DSP_SEL and not DP_SEL and not SRTC_SEL and not BSRAM_SEL and not OBC1_SEL;
	

	DSP_CS_N <= not DSP_SEL;

	DSPn : entity work.DSPn
	port map(
		CLK			=> MCLK,
		CE				=> DSP_CE,
		RST_N			=> RST_N and MAP_DSP_SEL,
		ENABLE		=> ENABLE,
		A0				=> DSP_A0,
		DI				=> DI,
		DO				=> DSP_DO,
		CS_N			=> DSP_CS_N,
		RD_N			=> CPURD_N,
		WR_N			=> CPUWR_N,

		DP_ADDR     => CA(11 downto 0),
		DP_SEL      => DP_SEL,

		VER			=> MAP_CTRL(3)&MAP_CTRL(5 downto 4),

		BRK_OUT		=> BRK_OUT,
		DBG_REG  	=> DBG_REG,
		DBG_DAT_IN	=> DBG_DAT_IN,
		DBG_DAT_OUT	=> DBG_DAT_OUT,
		DBG_DAT_WR	=> DBG_DAT_WR
	);

	OBC1 : entity work.OBC1
	port map(
		CLK			=> MCLK,
		RST_N			=> RST_N and MAP_OBC1_SEL,
		ENABLE		=> ENABLE,
		
		CA				=> CA,
		DI				=> DI,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		
		CS				=> OBC1_SEL,
				
		SRAM_A		=> OBC1_SRAM_A,
		SRAM_DI  	=> BSRAM_Q,
		SRAM_DO		=> OBC1_SRAM_DO
	);
	
	SRTC : entity work.SRTC
	port map(
		CLK			=> MCLK,

		A0				=> CA(0),
		DI				=> DI,
		DO				=> SRTC_DO,
		CS				=> SRTC_SEL,
		CPURD_N		=> CPURD_N,
		CPUWR_N		=> CPUWR_N,
		
		SYSCLKF_CE	=> SYSCLKF_CE,
		
		EXT_RTC		=> EXT_RTC
	);
	
	ROM_RD <= (SYSCLKF_CE or SYSCLKR_CE) when rising_edge(MCLK);

	ROM_ADDR <= CART_ADDR and ROM_MASK;
	ROM_CE_N <= ROMSEL_N;
	ROM_OE_N <= not ROM_RD;
	ROM_WORD	<= '0';

	BSRAM_ADDR <= "0000000" & OBC1_SRAM_A when OBC1_SEL = '1' else BRAM_ADDR and BSRAM_MASK(19 downto 0);
	BSRAM_CE_N <= not (BSRAM_SEL or OBC1_SEL);
	BSRAM_OE_N <= CPURD_N;
	BSRAM_WE_N <= CPUWR_N;
	BSRAM_D    <= OBC1_SRAM_DO when OBC1_SEL = '1' else DI;
	
	process(MCLK, RST_N)
	begin
		if RST_N = '0' then
			OPENBUS <= (others => '1');
		elsif rising_edge(MCLK) then
			if SYSCLKR_CE = '1' then
				OPENBUS <= DI;
			end if;
		end if;
	end process;
	
	DO <= ROM_Q(7 downto 0) when ROM_SEL = '1' else
			DSP_DO when DSP_SEL = '1' or DP_SEL = '1' else
			SRTC_DO when SRTC_SEL = '1' else
			BSRAM_Q when BSRAM_SEL = '1' or OBC1_SEL = '1' else
			OPENBUS;

	IRQ_N <= '1';

end rtl;
