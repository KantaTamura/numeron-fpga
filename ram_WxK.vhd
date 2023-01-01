library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity ram_WxK is
  generic(K: integer := 4;
          W: integer := 2);
  port(clk: in std_logic;
       din: in std_logic_vector (K-1 downto 0);
       wadr: in std_logic_vector (W-1 downto 0);
       radr: in std_logic_vector (W-1 downto 0);
       we: in std_logic;
       dout: out std_logic_vector (K-1 downto 0));
end ram_WxK;

architecture rtl of ram_WxK is
  type mem is array(0 to (2**W)-1) of std_logic_vector(K-1 downto 0);
  signal ram_block: mem;
begin
  process(clk)
  begin
    if(clk'event and clk = '1') then
      if(we = '1') then
        ram_block(conv_integer(wadr)) <= din;
      end if;
      dout <= ram_block(conv_integer(radr));
    end if;
  end process;
end rtl;
