library ieee;
use ieee.std_logic_1164.all;

entity dec_decoder is
  port(q  : in  std_logic_vector(3 downto 0);
       ans: out std_logic_vector(3 downto 0));
end dec_decoder;

architecture rtl of dec_decoder is
    signal d1, d2, d3, d4, q1, q2, q3, q4, qb1, qb2, qb3, qb4: std_logic;
begin
    ans <= "1001" when q >= "1001" else q;
end rtl;
  
