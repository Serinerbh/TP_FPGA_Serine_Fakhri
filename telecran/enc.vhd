library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity enc is
    generic (
        N : natural := 10   -- taille du compteur
    );
    port (
        clk     : in  std_logic;
        rst_n   : in  std_logic;
        ch_a    : in  std_logic;
        ch_b    : in  std_logic;
        count   : out std_logic_vector(N-1 downto 0)
    );
end entity enc;

architecture rtl of enc is

    -- mémorisation des signaux
    signal a_prev, a_curr : std_logic := '0';
    signal b_prev, b_curr : std_logic := '0';

    -- compteur interne signé
    signal cnt : signed(N-1 downto 0) := (others => '0');

begin


    process(clk, rst_n)
    begin
        if rst_n = '0' then
            a_prev <= '0';
            a_curr <= '0';
            b_prev <= '0';
            b_curr <= '0';
        elsif rising_edge(clk) then
            a_prev <= a_curr;
            a_curr <= ch_a;

            b_prev <= b_curr;
            b_curr <= ch_b;
        end if;
    end process;

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            cnt <= (others => '0');

        elsif rising_edge(clk) then

            -- FRONT SUR A → INCRÉMENTATION
            if (a_prev = '0' and a_curr = '1') then
                if b_curr = '0' then
                    cnt <= cnt + 1;
                end if;

            elsif (a_prev = '1' and a_curr = '0') then
                if b_curr = '1' then
                    cnt <= cnt + 1;
                end if;
            end if;

            -- FRONT SUR B → DÉCRÉMENTATION
            if (b_prev = '0' and b_curr = '1') then
                if a_curr = '0' then
                    cnt <= cnt - 1;
                end if;

            elsif (b_prev = '1' and b_curr = '0') then
                if a_curr = '1' then
                    cnt <= cnt - 1;
                end if;
            end if;

        end if;
    end process;

    count <= std_logic_vector(cnt);

end architecture rtl;
