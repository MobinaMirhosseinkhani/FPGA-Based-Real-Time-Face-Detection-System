module face_detection (
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg face_detected
);

    // Parameters - reduced sizes to save resources
    parameter IMG_WIDTH = 640;
    parameter WINDOW_SIZE = 32;
    
    // Reduced buffer size
    reg [7:0] line_buffer [0:31];  // Only store recent pixels
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    
    // Simplified feature detection
    reg [7:0] avg_intensity;
    reg [7:0] prev_intensity;
    
    // State machine with fewer states
    reg [1:0] state;
    localparam IDLE = 0,
               DETECT = 1,
               MARK = 2;
               
    // Thresholds
    parameter INTENSITY_THRESH = 8'h40;
    parameter DIFF_THRESH = 8'h20;

    // RGB565 to grayscale - simplified calculation
    function [7:0] rgb565_to_gray;
        input [15:0] rgb;
        begin
            rgb565_to_gray = {rgb[15:11], 3'b0} + // Red
                            {rgb[10:5], 2'b0} +    // Green
                            {rgb[4:0], 3'b0};      // Blue
        end
    endfunction

    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_x <= 0;
            pixel_y <= 0;
            face_detected <= 0;
            pixel_out <= 0;
            avg_intensity <= 0;
            prev_intensity <= 0;
        end
        else if (data_valid_in) begin
            // Update position
            if (pixel_x == IMG_WIDTH-1) begin
                pixel_x <= 0;
                pixel_y <= pixel_y + 1;
            end
            else begin
                pixel_x <= pixel_x + 1;
            end

            // Convert to grayscale
            prev_intensity <= avg_intensity;
            avg_intensity <= rgb565_to_gray(pixel_in);

            case (state)
                IDLE: begin
                    if (pixel_x > WINDOW_SIZE) begin
                        state <= DETECT;
                    end
                    pixel_out <= pixel_in;
                end

                DETECT: begin
                    // Simple detection based on intensity difference
                    if (abs_diff(avg_intensity, prev_intensity) > DIFF_THRESH &&
                        avg_intensity > INTENSITY_THRESH) begin
                        state <= MARK;
                        face_detected <= 1;
                    end
                    else begin
                        face_detected <= 0;
                        pixel_out <= pixel_in;
                    end
                end

                MARK: begin
                    // Mark detected region
                    if (face_detected) begin
                        pixel_out <= 16'hF800;  // Red marker
                        state <= IDLE;
                    end
                    else begin
                        pixel_out <= pixel_in;
                        state <= DETECT;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Simple absolute difference
    function [7:0] abs_diff;
        input [7:0] a, b;
        begin
            abs_diff = (a > b) ? (a - b) : (b - a);
        end
    endfunction

endmodule