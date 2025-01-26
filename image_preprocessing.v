module image_preprocessing (
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg data_valid_out
);

    // Parameters
    parameter IMG_WIDTH = 640;
    
    // Simplified 3x2 window for processing
    reg [15:0] prev_pixel;
    reg [15:0] curr_pixel;
    
    // Position counter - only need x position
    reg [9:0] x_pos;
    
    // Simple moving average
    wire [4:0] r_avg = (prev_pixel[15:11] + curr_pixel[15:11]) >> 1;
    wire [5:0] g_avg = (prev_pixel[10:5] + curr_pixel[10:5]) >> 1;
    wire [4:0] b_avg = (prev_pixel[4:0] + curr_pixel[4:0]) >> 1;
    
    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= 0;
            prev_pixel <= 0;
            curr_pixel <= 0;
            pixel_out <= 0;
            data_valid_out <= 0;
        end
        else if (data_valid_in) begin
            // Update position
            if (x_pos == IMG_WIDTH-1)
                x_pos <= 0;
            else
                x_pos <= x_pos + 1;
                
            // Shift pixels
            prev_pixel <= curr_pixel;
            curr_pixel <= pixel_in;
            
            // Simple smoothing
            if (x_pos > 0) begin
                pixel_out <= {r_avg, g_avg, b_avg};
                data_valid_out <= 1;
            end
            else begin
                pixel_out <= pixel_in;
                data_valid_out <= 1;
            end
        end
        else begin
            data_valid_out <= 0;
        end
    end

endmodule