library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_trigonometry_cordicsincosq15primitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_request : in std_logic;
        ctor_phasebits : in std_logic_vector(15 downto 0);
        ctor_valid : in boolean;
        ctor_acknowledge : out std_logic;
        ctor_sine : out signed(31 downto 0);
        ctor_cosine : out signed(31 downto 0);
        ctor_success : out boolean
    );
end;

architecture rtl of livt_math_trigonometry_cordicsincosq15primitive is
    subtype coordinate_t is signed(18 downto 0);
    subtype angle_t is signed(19 downto 0);
    subtype q15_t is signed(15 downto 0);

    type worker_state_t is (idle, rotate, finish_sine, finish_cosine);
    signal worker_state : worker_state_t := idle;
    signal pending : std_logic := '0';
    signal x, y : coordinate_t := (others => '0');
    signal residual : angle_t := (others => '0');
    signal iteration : natural range 0 to 15 := 0;
    signal sine_q15, cosine_q15 : q15_t := (others => '0');
    signal round_source : coordinate_t := (others => '0');
    signal rounded_value : q15_t := (others => '0');

    function atan_phase(index : natural) return angle_t is
    begin
        case index is
            when 0 => return to_signed(131072, angle_t'length);
            when 1 => return to_signed(77376, angle_t'length);
            when 2 => return to_signed(40884, angle_t'length);
            when 3 => return to_signed(20753, angle_t'length);
            when 4 => return to_signed(10417, angle_t'length);
            when 5 => return to_signed(5213, angle_t'length);
            when 6 => return to_signed(2607, angle_t'length);
            when 7 => return to_signed(1304, angle_t'length);
            when 8 => return to_signed(652, angle_t'length);
            when 9 => return to_signed(326, angle_t'length);
            when 10 => return to_signed(163, angle_t'length);
            when 11 => return to_signed(81, angle_t'length);
            when 12 => return to_signed(41, angle_t'length);
            when 13 => return to_signed(20, angle_t'length);
            when 14 => return to_signed(10, angle_t'length);
            when others => return to_signed(5, angle_t'length);
        end case;
    end function;

    function round_q15(value : coordinate_t) return q15_t is
        variable rounded : coordinate_t;
    begin
        if value >= 0 then
            rounded := shift_right(value + 2, 2);
        else
            rounded := -shift_right(-value + 2, 2);
        end if;

        if rounded > 32767 then
            return to_signed(32767, q15_t'length);
        elsif rounded < -32768 then
            return to_signed(-32768, q15_t'length);
        end if;

        return resize(rounded, q15_t'length);
    end function;
begin
    ctor_sine <= resize(sine_q15, ctor_sine'length);
    ctor_cosine <= resize(cosine_q15, ctor_cosine'length);
    with worker_state select
        round_source <= y when finish_sine,
                        x when finish_cosine,
                        (others => '0') when others;
    rounded_value <= round_q15(round_source);

    process (ctor_lvt_context_in.clk)
        variable old_x, old_y : coordinate_t;
        variable shifted_x, shifted_y : coordinate_t;
        variable angle : angle_t;
        variable phase_value : signed(15 downto 0);
        variable scaled_phase : angle_t;
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '1' then
                worker_state <= idle;
                pending <= '0';
                x <= (others => '0');
                y <= (others => '0');
                residual <= (others => '0');
                iteration <= 0;
                ctor_acknowledge <= '0';
                sine_q15 <= (others => '0');
                cosine_q15 <= (others => '0');
                ctor_success <= false;
            elsif worker_state = rotate then
                old_x := x;
                old_y := y;
                shifted_x := shift_right(old_x, iteration);
                shifted_y := shift_right(old_y, iteration);
                angle := atan_phase(iteration);

                if residual >= 0 then
                    x <= old_x - shifted_y;
                    y <= old_y + shifted_x;
                    residual <= residual - angle;
                else
                    x <= old_x + shifted_y;
                    y <= old_y - shifted_x;
                    residual <= residual + angle;
                end if;

                if iteration = 15 then
                    worker_state <= finish_sine;
                else
                    iteration <= iteration + 1;
                end if;
            elsif worker_state = finish_sine then
                sine_q15 <= rounded_value;
                worker_state <= finish_cosine;
            elsif worker_state = finish_cosine then
                cosine_q15 <= rounded_value;
                ctor_success <= true;
                ctor_acknowledge <= pending;
                worker_state <= idle;
            elsif ctor_request /= ctor_acknowledge then
                pending <= ctor_request;
                sine_q15 <= (others => '0');
                cosine_q15 <= (others => '0');
                ctor_success <= false;

                if not ctor_valid then
                    ctor_acknowledge <= ctor_request;
                else
                    iteration <= 0;
                    y <= (others => '0');
                    phase_value := signed(ctor_phasebits);
                    scaled_phase := shift_left(resize(phase_value, residual'length), 4);

                    if phase_value > 16384 or phase_value < -16384 then
                        x <= to_signed(-79594, x'length);
                        scaled_phase(19) := not scaled_phase(19);
                        residual <= scaled_phase;
                    else
                        x <= to_signed(79594, x'length);
                        residual <= scaled_phase;
                    end if;

                    worker_state <= rotate;
                end if;
            end if;
        end if;
    end process;
end;
