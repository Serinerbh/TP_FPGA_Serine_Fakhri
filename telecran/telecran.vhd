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

    component hdmi_controler is
        port (
            i_clk           : in  std_logic;
            i_rst_n         : in  std_logic;
            o_hdmi_tx_clk   : out std_logic;
            o_hdmi_tx_de    : out std_logic;
            o_hdmi_tx_hs    : out std_logic;
            o_hdmi_tx_vs    : out std_logic;
            o_pixel_en      : out std_logic;
            o_pixel_address : out std_logic_vector(18 downto 0);
            s_x_counter     : out unsigned(9 downto 0);
            s_y_counter     : out unsigned(9 downto 0)
        );
    end component;
     
    component dpram is
        generic (
            mem_size   : natural := 720 * 480;  -- cohérent avec ton fichier fourni
            data_width : natural := 8
        );
        port (
            i_clk_a    : in  std_logic;
            i_clk_b    : in  std_logic;
            i_data_a   : in  std_logic_vector(data_width-1 downto 0);
            i_data_b   : in  std_logic_vector(data_width-1 downto 0);
            i_addr_a   : in  natural range 0 to mem_size-1;
            i_addr_b   : in  natural range 0 to mem_size-1;
            i_we_a     : in  std_logic := '0';
            i_we_b     : in  std_logic := '0';
            o_q_a      : out std_logic_vector(data_width-1 downto 0);
            o_q_b      : out std_logic_vector(data_width-1 downto 0)
        );
    end component;

    -- SIGNALS
    signal s_clk_27       : std_logic;
    signal s_rst_n        : std_logic;
    signal s_count_left   : std_logic_vector(9 downto 0);
    signal s_count_right  : std_logic_vector(9 downto 0);

    -- hdmi counters
    signal s_x_counter : unsigned(9 downto 0);
    signal s_y_counter : unsigned(9 downto 0);

    -- Data Enable interne (pour éviter de lire le port out)
    signal s_hdmi_de : std_logic;

    -- framebuffer
    signal s_pixel_write_data : std_logic_vector(7 downto 0) := x"FF"; 
    signal s_pixel_read_data  : std_logic_vector(7 downto 0);
    signal s_pixel_write_addr : natural range 0 to 720*480-1;
    signal s_pixel_read_addr  : natural range 0 to 720*480-1;
    signal s_pixel_we         : std_logic := '0';

    -- Diviseur d'horloge
    signal slow_clk : std_logic := '0';
    signal div_cnt  : unsigned(15 downto 0) := (others => '0');

begin

    -- DIVISEUR D'HORLOGE
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

    -- I2C HDMI Config
    I2C_HDMI_Config0 : I2C_HDMI_Config
        port map (
            iCLK       => i_clk_50,
            iRST_N     => i_rst_n,
            I2C_SCLK   => io_hdmi_i2c_scl,
            I2C_SDAT   => io_hdmi_i2c_sda,
            HDMI_TX_INT=> i_hdmi_tx_int
        );

    -- Encodeurs
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

    -- HDMI Controller
    hdmi0 : hdmi_controler
        port map (
            i_clk           => s_clk_27,
            i_rst_n         => s_rst_n,
            o_hdmi_tx_clk   => o_hdmi_tx_clk,
            o_hdmi_tx_de    => s_hdmi_de,    -- vers signal interne
            o_hdmi_tx_hs    => o_hdmi_tx_hs,
            o_hdmi_tx_vs    => o_hdmi_tx_vs,
            o_pixel_en      => open,
            o_pixel_address => open,
            s_x_counter     => s_x_counter,
            s_y_counter     => s_y_counter
        );

    -- Expose le DE interne vers le port de sortie
    o_hdmi_tx_de <= s_hdmi_de;

    -- RAM dual-port
    pixel_mem : dpram
        generic map (
            mem_size   => 720*480,
            data_width => 8
        )
        port map (
            i_clk_a    => slow_clk,
            i_clk_b    => s_clk_27,
            i_data_a   => s_pixel_write_data,
            i_data_b   => (others => '0'),
            i_addr_a   => s_pixel_write_addr,
            i_addr_b   => s_pixel_read_addr,
            i_we_a     => s_pixel_we,
            i_we_b     => '0',
            o_q_a      => open,
            o_q_b      => s_pixel_read_data
        );

    -- écriture pixel (encodeurs)
    process(s_count_left, s_count_right)
    begin
        s_pixel_write_addr <= to_integer(unsigned(s_count_right)) * 720 + to_integer(unsigned(s_count_left));
        s_pixel_we <= '1';
    end process;

    -- lecture pixel (HDMI)
    s_pixel_read_addr <= to_integer(s_y_counter) * 720 + to_integer(s_x_counter);

    -- affichage HDMI (masqué par DE interne)
    process(s_pixel_read_data, s_hdmi_de)
    begin
        if s_hdmi_de = '1' then
            if s_pixel_read_data(0) = '1' then
                o_hdmi_tx_d <= x"FFFFFF"; -- blanc
            else
                o_hdmi_tx_d <= x"000000"; -- noir
            end if;
        else
            o_hdmi_tx_d <= x"000000";
        end if;
    end process;

    -- LEDS
    o_leds      <= s_count_left;
    o_de10_leds <= s_count_right(7 downto 0);

end architecture rtl;
