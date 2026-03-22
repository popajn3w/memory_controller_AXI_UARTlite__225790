module rshift_k_nbit_reg #(
    parameter width = 32,
    parameter rshift_bits = 8
)(
    input en,
    input rstn,
    input clk,
    input [rshift_bits-1 : 0] d,
    output reg [width-1  : 0] q
);


always_ff @(posedge clk) begin
    if (!rstn)
        q <= 0;
    else begin
        if (en)
            q <= {d, q[width-1 : rshift_bits]};
        else
            q <= q;
    end
end

endmodule
