library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_sqrt_unsignedsqrt32pipelineprimitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_inputvalid : in boolean;
        ctor_inputready : out boolean;
        ctor_radicand : in std_logic_vector(31 downto 0);
        ctor_inputtag : in std_logic_vector(63 downto 0);
        ctor_outputvalid : out boolean;
        ctor_outputready : in boolean;
        ctor_root : out std_logic_vector(31 downto 0);
        ctor_outputtag : out std_logic_vector(63 downto 0)
    );
end;

architecture rtl of livt_math_sqrt_unsignedsqrt32pipelineprimitive is
    type radicand_array_t is array (0 to 15) of unsigned(31 downto 0);
    type remainder_array_t is array (0 to 15) of unsigned(33 downto 0);
    type root_array_t is array (0 to 15) of unsigned(15 downto 0);
    type tag_array_t is array (0 to 15) of std_logic_vector(63 downto 0);
    signal valid_pipe : std_logic_vector(0 to 15) := (others => '0');
    signal radicand_pipe : radicand_array_t;
    signal remainder_pipe : remainder_array_t;
    signal root_pipe : root_array_t;
    signal tag_pipe : tag_array_t;
    signal advance : boolean;
begin
    advance <= valid_pipe(15) = '0' or ctor_outputready;
    ctor_inputready <= advance and ctor_lvt_context_in.rst = '0';
    ctor_outputvalid <= valid_pipe(15) = '1' and ctor_lvt_context_in.rst = '0';
    ctor_root <= std_logic_vector(resize(root_pipe(15), 32)) when valid_pipe(15) = '1' else (others => '0');
    ctor_outputtag <= tag_pipe(15) when valid_pipe(15) = '1' else (others => '0');

    process (ctor_lvt_context_in.clk)
        variable next_radicand : unsigned(31 downto 0);
        variable next_remainder, trial : unsigned(33 downto 0);
        variable next_root : unsigned(15 downto 0);
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '1' then
                valid_pipe <= (others => '0');
            elsif advance then
                valid_pipe(0) <= '1' when ctor_inputvalid else '0';
                tag_pipe(0) <= ctor_inputtag;
                next_radicand := shift_left(unsigned(ctor_radicand), 2);
                next_remainder := (others => '0');
                next_remainder(1 downto 0) := unsigned(ctor_radicand(31 downto 30));
                next_root := (others => '0');
                trial := (others => '0');
                trial(0) := '1';

                if next_remainder >= trial then
                    next_remainder := next_remainder - trial;
                    next_root(0) := '1';
                end if;

                radicand_pipe(0) <= next_radicand;
                remainder_pipe(0) <= next_remainder;
                root_pipe(0) <= next_root;

                for stage in 1 to 15 loop
                    valid_pipe(stage) <= valid_pipe(stage - 1);
                    if valid_pipe(stage - 1) = '1' then
                        tag_pipe(stage) <= tag_pipe(stage - 1);
                        next_radicand := shift_left(radicand_pipe(stage - 1), 2);
                        next_remainder := shift_left(remainder_pipe(stage - 1), 2);
                        next_remainder(1 downto 0) := radicand_pipe(stage - 1)(31 downto 30);
                        next_root := shift_left(root_pipe(stage - 1), 1);
                        trial := shift_left(resize(next_root, 34), 1) + 1;

                        if next_remainder >= trial then
                            next_remainder := next_remainder - trial;
                            next_root(0) := '1';
                        end if;

                        radicand_pipe(stage) <= next_radicand;
                        remainder_pipe(stage) <= next_remainder;
                        root_pipe(stage) <= next_root;
                    else
                        tag_pipe(stage) <= (others => '0');
                        radicand_pipe(stage) <= (others => '0');
                        remainder_pipe(stage) <= (others => '0');
                        root_pipe(stage) <= (others => '0');
                    end if;
                end loop;
            end if;
        end if;
    end process;
end;
