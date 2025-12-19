library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;
use pll.all;

entity telecran is
    port (
        -- FPGA
        i_clk_50: in std_logic;

        -- HDMI
        io_hdmi_i2c_scl : inout std_logic;
        io_hdmi_i2c_sda : inout std_logic;
        o_hdmi_tx_clk   : out std_logic;
        o_hdmi_tx_d     : out std_logic_vector(23 downto 0);
        o_hdmi_tx_de    : out std_logic;
        o_hdmi_tx_hs    : out std_logic;
        i_hdmi_tx_int   : in std_logic;
        o_hdmi_tx_vs    : out std_logic;

        -- KEYs
        i_rst_n : in std_logic;
          
        -- LEDs
        o_leds      : out std_logic_vector(9 downto 0);
        o_de10_leds : out std_logic_vector(7 downto 0);

        -- Coder
        i_left_ch_a  : in std_logic;
        i_left_ch_b  : in std_logic;
        i_left_pb    : in std_logic;
        i_right_ch_a : in std_logic;
        i_right_ch_b : in std_logic;
        i_right_pb   : in std_logic
    );
end entity telecran;

architecture rtl of telecran is

    
    -- COMPONENTS
    
    component I2C_HDMI_Config 
        port (
            iCLK       : in std_logic;
            iRST_N     : in std_logic;
            I2C_SCLK   : out std_logic;
            I2C_SDAT   : inout std_logic;
            HDMI_TX_INT: in std_logic
        );
    end component;
     
    component pll 
        port (
            refclk   : in std_logic;
            rst      : in std_logic;
            outclk_0 : out std_logic;
            locked   : out std_logic
        );
    end component;
    
    component enc is
        generic (
            N : natural := 10
        );
        port (
            clk   : in  std_logic;
            rst_n : in  std_logic;
            ch_a  : in  std_logic;
            ch_b  : in  std_logic;
            count : out std_logic_vector(N-1 downto 0)
        );
    end component;

    
    -- SIGNALS
    
    signal s_clk_27       : std_logic;
    signal s_rst_n        : std_logic;
    signal s_count_left   : std_logic_vector(9 downto 0);
    signal s_count_right  : std_logic_vector(9 downto 0);

    -- Diviseur d'horloge
    signal slow_clk : std_logic := '0';
    signal div_cnt  : unsigned(15 downto 0) := (others => '0');

begin

    
    -- DIVISEUR D'HORLOGE (process placé APRÈS begin)
    
    process(i_clk_50, i_rst_n)
    begin
        if i_rst_n = '0' then
            div_cnt  <= (others => '0');
            slow_clk <= '0';
        elsif rising_edge(i_clk_50) then
            if div_cnt = 49999 then
                div_cnt  <= (others => '0');
                slow_clk <= not slow_clk;
            else
                div_cnt <= div_cnt + 1;
            end if;
        end if;
    end process;

    
    -- PLL
    
    pll0 : pll
        port map (
            refclk   => i_clk_50,
            rst      => not i_rst_n,
            outclk_0 => s_clk_27,
            locked   => s_rst_n
        );


    I2C_HDMI_Config0 : I2C_HDMI_Config
        port map (
            iCLK       => i_clk_50,
            iRST_N     => i_rst_n,
            I2C_SCLK   => io_hdmi_i2c_scl,
            I2C_SDAT   => io_hdmi_i2c_sda,
            HDMI_TX_INT=> i_hdmi_tx_int
        );


    enc_left : enc
        generic map ( N => 10 )
        port map (
            clk   => slow_clk,
            rst_n => i_rst_n,
            ch_a  => i_left_ch_a,
            ch_b  => i_left_ch_b,
            count => s_count_left
        );

		  
    enc_right : enc
        generic map ( N => 10 )
        port map (
            clk   => slow_clk,
            rst_n => i_rst_n,
            ch_a  => i_right_ch_a,
            ch_b  => i_right_ch_b,
            count => s_count_right
        );

    
    -- LEDS
    
    o_leds      <= s_count_left;
    o_de10_leds <= s_count_right(7 downto 0);

end architecture rtl;
