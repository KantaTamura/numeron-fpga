library ieee;
use ieee.std_logic_1164.all;

entity chattering_sw is
    port(clk, xrst: in std_logic;  
        button: in std_logic;
        no_chattering: out std_logic);
end chattering_sw;

architecture gate_level of chattering_sw is
    signal d1, d2, d3, d4, q1, q2, q3, q4, qb1, qb2, qb3, qb4: std_logic;
    signal rising, result: std_logic;
    component d_flip_flop_w_reset
        port(clk, xrst, d: in std_logic;  
             q, qb: out std_logic);
    end component;  
begin
    dff1: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => button, q => q1, qb => qb1);
    dff2: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => q1, q => q2, qb => qb2);
    dff3: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => q2, q => q3, qb => qb3);

    no_chattering <= q1 and q2 and q3;
end gate_level;
  
entity chattering_bt is
    port(clk, xrst: in std_logic;  
        button: in std_logic;
        no_chattering: out std_logic);
end chattering_bt;

architecture gate_level of chattering_bt is
    signal d1, d2, d3, d4, q1, q2, q3, q4, qb1, qb2, qb3, qb4: std_logic;
    signal rising, result: std_logic;
    component d_flip_flop_w_reset
        port(clk, xrst, d: in std_logic;  
             q, qb: out std_logic);
    end component;  
begin
    dff1: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => button, q => q1, qb => qb1);
    dff2: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => q1, q => q2, qb => qb2);
    dff3: d_flip_flop_w_reset port map(clk => clk, xrst => xrst, d => q2, q => q3, qb => qb3);

    no_chattering <= q1 and q2 and qb3;
end gate_level;

entity d_flip_flop_w_reset is 
    port(clk, xrst, d: in std_logic;
         q, qb: out std_logic);
end d_flip_flop_w_reset;

architecture rtl of d_flip_flop_w_reset is 
    signal q1: std_logic;
begin
    q <= q1;
    qb <= not q1;
    process(clk, xrst)
    begin
        if(xrst = '0') then
            q1 <= '0';
        elsif(clk'event and clk = '1') then
            q1 <= d;
        end if;
    end process;
end rtl;