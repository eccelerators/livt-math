library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_trigonometry_cordicatan2magnitudeq15primitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_request : in std_logic;
        ctor_xbits : in std_logic_vector(15 downto 0);
        ctor_ybits : in std_logic_vector(15 downto 0);
        ctor_valid : in boolean;
        ctor_acknowledge : out std_logic;
        ctor_phase : out signed(31 downto 0);
        ctor_magnitude : out unsigned(31 downto 0);
        ctor_success : out boolean
    );
end;

architecture rtl of livt_math_trigonometry_cordicatan2magnitudeq15primitive is
    subtype coordinate_t is signed(19 downto 0);
    subtype angle_t is signed(20 downto 0);
    subtype product_t is signed(38 downto 0);
    subtype phase_t is signed(15 downto 0);
    subtype magnitude_t is unsigned(15 downto 0);

    type worker_state_t is (
        idle,
        normalize,
        vector,
        capture_phase,
        denormalize,
        scale_gain,
        finish
    );
    signal worker_state : worker_state_t := idle;
    signal pending : std_logic := '0';
    signal x, y : coordinate_t := (others => '0');
    signal accumulated_phase : angle_t := (others => '0');
    signal normalization : natural range 0 to 14 := 0;
    signal normalize_step : natural range 0 to 13 := 0;
    signal iteration : natural range 0 to 15 := 0;
    signal denormalize_step : natural range 0 to 13 := 0;
    signal gain_step : natural range 0 to 6 := 0;
    signal gain_accumulator : product_t := (others => '0');
    signal phase_result : phase_t := (others => '0');
    signal magnitude_result : magnitude_t := (others => '0');

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

    function absolute_coordinate(value : coordinate_t) return coordinate_t is
    begin
        if value < 0 then
            return -value;
        end if;

        return value;
    end function;

    function round_phase(value : angle_t) return phase_t is
        variable rounded : angle_t;
    begin
        if value >= 0 then
            rounded := shift_right(value + 8, 4);
        else
            rounded := -shift_right(-value + 8, 4);
        end if;

        if rounded >= 32768 then
            rounded := rounded - 65536;
        elsif rounded < -32768 then
            rounded := rounded + 65536;
        end if;

        return resize(rounded, phase_t'length);
    end function;

    function round_magnitude(value : product_t) return magnitude_t is
        variable rounded : product_t;
    begin
        rounded := shift_right(value + 524288, 20);
        if rounded > 46341 then
            return to_unsigned(46341, magnitude_t'length);
        end if;

        return resize(unsigned(rounded), magnitude_t'length);
    end function;

    function gain_term(value : coordinate_t; index : natural) return product_t is
        variable widened : product_t;
    begin
        widened := resize(value, product_t'length);
        case index is
            when 0 => return shift_left(widened, 2);
            when 1 => return shift_left(widened, 4);
            when 2 => return -shift_left(widened, 6);
            when 3 => return -shift_left(widened, 9);
            when 4 => return -shift_left(widened, 12);
            when 5 => return shift_left(widened, 15);
            when others => return shift_left(widened, 17);
        end case;
    end function;
begin
    ctor_phase <= resize(phase_result, ctor_phase'length);
    ctor_magnitude <= resize(magnitude_result, ctor_magnitude'length);

    process (ctor_lvt_context_in.clk)
        variable input_x, input_y : signed(15 downto 0);
        variable widened_x, widened_y : coordinate_t;
        variable old_x, old_y : coordinate_t;
        variable shifted_x, shifted_y : coordinate_t;
        variable angle : angle_t;
        variable term, next_accumulator : product_t;
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if ctor_lvt_context_in.rst = '1' then
                worker_state <= idle;
                pending <= '0';
                x <= (others => '0');
                y <= (others => '0');
                accumulated_phase <= (others => '0');
                normalization <= 0;
                normalize_step <= 0;
                iteration <= 0;
                denormalize_step <= 0;
                gain_step <= 0;
                gain_accumulator <= (others => '0');
                phase_result <= (others => '0');
                magnitude_result <= (others => '0');
                ctor_acknowledge <= '0';
                ctor_success <= false;
            elsif worker_state = normalize then
                if absolute_coordinate(x) < 65536
                    and absolute_coordinate(y) < 65536 then
                    x <= shift_left(x, 1);
                    y <= shift_left(y, 1);
                    normalization <= normalization + 1;
                end if;

                if normalize_step = 13 then
                    iteration <= 0;
                    worker_state <= vector;
                else
                    normalize_step <= normalize_step + 1;
                end if;
            elsif worker_state = vector then
                old_x := x;
                old_y := y;
                shifted_x := shift_right(old_x, iteration);
                shifted_y := shift_right(old_y, iteration);
                angle := atan_phase(iteration);

                if old_y >= 0 then
                    x <= old_x + shifted_y;
                    y <= old_y - shifted_x;
                    accumulated_phase <= accumulated_phase + angle;
                else
                    x <= old_x - shifted_y;
                    y <= old_y + shifted_x;
                    accumulated_phase <= accumulated_phase - angle;
                end if;

                if iteration = 15 then
                    worker_state <= capture_phase;
                else
                    iteration <= iteration + 1;
                end if;
            elsif worker_state = capture_phase then
                phase_result <= round_phase(accumulated_phase);
                denormalize_step <= 0;
                worker_state <= denormalize;
            elsif worker_state = denormalize then
                if denormalize_step < normalization then
                    x <= shift_right(x, 1);
                end if;

                if denormalize_step = 13 then
                    gain_accumulator <= (others => '0');
                    gain_step <= 0;
                    worker_state <= scale_gain;
                else
                    denormalize_step <= denormalize_step + 1;
                end if;
            elsif worker_state = scale_gain then
                term := gain_term(x, gain_step);
                next_accumulator := gain_accumulator + term;
                gain_accumulator <= next_accumulator;

                if gain_step = 6 then
                    magnitude_result <= round_magnitude(next_accumulator);
                    worker_state <= finish;
                else
                    gain_step <= gain_step + 1;
                end if;
            elsif worker_state = finish then
                ctor_success <= true;
                ctor_acknowledge <= pending;
                worker_state <= idle;
            elsif ctor_request /= ctor_acknowledge then
                pending <= ctor_request;
                phase_result <= (others => '0');
                magnitude_result <= (others => '0');
                ctor_success <= false;

                if not ctor_valid then
                    ctor_acknowledge <= ctor_request;
                else
                    input_x := signed(ctor_xbits);
                    input_y := signed(ctor_ybits);
                    widened_x := shift_left(resize(input_x, x'length), 2);
                    widened_y := shift_left(resize(input_y, y'length), 2);

                    if input_x < 0 then
                        x <= -widened_x;
                        y <= -widened_y;
                        if input_y >= 0 then
                            accumulated_phase <= to_signed(524288, angle_t'length);
                        else
                            accumulated_phase <= to_signed(-524288, angle_t'length);
                        end if;
                    else
                        x <= widened_x;
                        y <= widened_y;
                        accumulated_phase <= (others => '0');
                    end if;

                    normalization <= 0;
                    normalize_step <= 0;
                    worker_state <= normalize;
                end if;
            end if;
        end if;
    end process;
end;
