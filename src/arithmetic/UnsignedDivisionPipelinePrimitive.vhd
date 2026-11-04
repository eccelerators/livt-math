library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_arithmetic_unsigneddivisionpipelineprimitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_inputvalid : in boolean;
        ctor_inputready : out boolean;
        ctor_dividend : in std_logic_vector(63 downto 0);
        ctor_divisor : in std_logic_vector(63 downto 0);
        ctor_inputtag : in std_logic_vector(63 downto 0);
        ctor_outputvalid : out boolean;
        ctor_outputready : in boolean;
        ctor_quotient : out std_logic_vector(63 downto 0);
        ctor_remainder : out std_logic_vector(63 downto 0);
        ctor_outputtag : out std_logic_vector(63 downto 0);
        ctor_failed : out boolean
    );
end;

architecture rtl of livt_math_arithmetic_unsigneddivisionpipelineprimitive is
    type word_array_t is array (0 to 63) of unsigned(63 downto 0);
    type remainder_array_t is array (0 to 63) of unsigned(64 downto 0);
    type tag_array_t is array (0 to 63) of std_logic_vector(63 downto 0);
    signal valid_pipe : std_logic_vector(0 to 63) := (others => '0');
    signal failed_pipe : std_logic_vector(0 to 63) := (others => '0');
    signal dividend_pipe, divisor_pipe, quotient_pipe : word_array_t;
    signal remainder_pipe : remainder_array_t;
    signal tag_pipe : tag_array_t;
    signal advance : boolean;
begin
    advance <= valid_pipe(63) = '0' or ctor_outputready;
    ctor_inputready <= advance and ctor_lvt_context_in.rst = '0';
    ctor_outputvalid <= valid_pipe(63) = '1' and ctor_lvt_context_in.rst = '0';
    ctor_quotient <= std_logic_vector(quotient_pipe(63)) when valid_pipe(63) = '1' else (others => '0');
    ctor_remainder <= std_logic_vector(remainder_pipe(63)(63 downto 0)) when valid_pipe(63) = '1' else (others => '0');
    ctor_outputtag <= tag_pipe(63) when valid_pipe(63) = '1' else (others => '0');
    ctor_failed <= failed_pipe(63) = '1';

    process (ctor_lvt_context_in.clk)
        variable next_remainder : unsigned(64 downto 0);
        variable next_quotient : unsigned(63 downto 0);
        variable bit_index : integer range 0 to 63;
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '1' then
                valid_pipe <= (others => '0');
                failed_pipe <= (others => '0');
            elsif advance then
                valid_pipe(0) <= '1' when ctor_inputvalid else '0';
                dividend_pipe(0) <= unsigned(ctor_dividend);
                divisor_pipe(0) <= unsigned(ctor_divisor);
                quotient_pipe(0) <= (others => '0');
                tag_pipe(0) <= ctor_inputtag;
                failed_pipe(0) <= '1' when unsigned(ctor_divisor) = 0 else '0';
                next_remainder := (others => '0');
                next_remainder(0) := ctor_dividend(63);

                if unsigned(ctor_divisor) /= 0 and next_remainder >= resize(unsigned(ctor_divisor), 65) then
                    remainder_pipe(0) <= next_remainder - resize(unsigned(ctor_divisor), 65);
                    quotient_pipe(0)(63) <= '1';
                else
                    remainder_pipe(0) <= next_remainder;
                end if;

                for stage in 1 to 63 loop
                    valid_pipe(stage) <= valid_pipe(stage - 1);
                    failed_pipe(stage) <= failed_pipe(stage - 1);
                    if valid_pipe(stage - 1) = '1' then
                        dividend_pipe(stage) <= dividend_pipe(stage - 1);
                        divisor_pipe(stage) <= divisor_pipe(stage - 1);
                        tag_pipe(stage) <= tag_pipe(stage - 1);
                        next_quotient := quotient_pipe(stage - 1);
                        next_remainder := shift_left(remainder_pipe(stage - 1), 1);
                        bit_index := 63 - stage;
                        next_remainder(0) := dividend_pipe(stage - 1)(bit_index);

                        if failed_pipe(stage - 1) = '0' and
                                next_remainder >= resize(divisor_pipe(stage - 1), 65) then
                            next_remainder := next_remainder - resize(divisor_pipe(stage - 1), 65);
                            next_quotient(bit_index) := '1';
                        end if;

                        remainder_pipe(stage) <= next_remainder;
                        quotient_pipe(stage) <= next_quotient;
                    else
                        dividend_pipe(stage) <= (others => '0');
                        divisor_pipe(stage) <= (others => '0');
                        quotient_pipe(stage) <= (others => '0');
                        remainder_pipe(stage) <= (others => '0');
                        tag_pipe(stage) <= (others => '0');
                    end if;
                end loop;
            end if;
        end if;
    end process;
end;
