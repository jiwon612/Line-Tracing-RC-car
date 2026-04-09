module pwm_generator #(
    parameter PWM_WIDTH = 8
)(
    input  wire clk,
    input  wire rst,
    input  wire [PWM_WIDTH-1:0] duty,
    output reg  pwm_out
);

    reg [PWM_WIDTH-1:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            pwm_out <= 0;
        end else begin
            counter <= counter + 1;
            pwm_out <= (counter < duty) ? 1'b1 : 1'b0;
        end
    end

endmodule
