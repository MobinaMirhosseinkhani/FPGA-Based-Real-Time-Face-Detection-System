module feature_based_detection (
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg face_detected
);

    // Basic parameters
    parameter IMG_WIDTH = 640;
    parameter IMG_HEIGHT = 480;
    parameter BORDER_THICKNESS = 3;

    // Thresholds
    parameter EYE_THRESHOLD = 50;
    parameter NOSE_THRESHOLD = 120;
    parameter MOUTH_THRESHOLD = 70;

    // Feature sizes
    parameter FEATURE_MIN_SIZE = 8;
    parameter FEATURE_MAX_SIZE = 25;
    parameter FACE_MIN_WIDTH = 80;
    parameter FACE_MAX_WIDTH = 160;

    // State definitions
    localparam IDLE = 0;
    localparam DETECT = 1;
    localparam FIND_EYES = 2;
    localparam FIND_NOSE = 3;
    localparam FIND_MOUTH = 4;
    localparam VERIFY = 5;
    localparam DRAW = 6;

    // Registers
    reg [9:0] x_pos;
    reg [9:0] y_pos;
    reg [9:0] face_left;
    reg [9:0] face_right;
    reg [9:0] face_top;
    reg [9:0] face_bottom;
    reg [2:0] state;
    
    reg face_boundary_valid;
    reg left_eye_found;
    reg right_eye_found;
    reg nose_found;
    reg mouth_found;
    
    reg [9:0] left_eye_x;
    reg [9:0] left_eye_y;
    reg [9:0] right_eye_x;
    reg [9:0] right_eye_y;
    reg [9:0] nose_x;
    reg [9:0] nose_y;
    reg [9:0] mouth_x;
    reg [9:0] mouth_y;

    // Color signals
    wire [7:0] gray;
    wire [7:0] r = {pixel_in[15:11], pixel_in[15:13]};
    wire [7:0] g = {pixel_in[10:5], pixel_in[10:9]};
    wire [7:0] b = {pixel_in[4:0], pixel_in[4:2]};
    
    // Simple grayscale conversion
    assign gray = (r + g + b) / 3;

    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            face_detected <= 0;
            face_boundary_valid <= 0;
            x_pos <= 0;
            y_pos <= 0;
            left_eye_found <= 0;
            right_eye_found <= 0;
            nose_found <= 0;
            mouth_found <= 0;
            pixel_out <= 0;
        end
        else if (data_valid_in) begin
            // Position update
            if (x_pos == IMG_WIDTH-1) begin
                x_pos <= 0;
                y_pos <= (y_pos == IMG_HEIGHT-1) ? 0 : y_pos + 1;
            end
            else begin
                x_pos <= x_pos + 1;
            end

            case (state)
                IDLE: begin
                    if (y_pos < IMG_HEIGHT/2) begin
                        state <= FIND_EYES;
                    end
                end

                FIND_EYES: begin
                    if (gray < EYE_THRESHOLD) begin
                        if (!left_eye_found) begin
                            left_eye_found <= 1;
                            left_eye_x <= x_pos;
                            left_eye_y <= y_pos;
                        end
                        else if (!right_eye_found &&
                                (x_pos - left_eye_x) >= FACE_MIN_WIDTH/3 &&
                                (x_pos - left_eye_x) <= FACE_MAX_WIDTH/3) begin
                            right_eye_found <= 1;
                            right_eye_x <= x_pos;
                            right_eye_y <= y_pos;
                            state <= FIND_NOSE;
                            
                            // Set initial face boundaries
                            face_left <= left_eye_x - (x_pos - left_eye_x)/2;
                            face_right <= x_pos + (x_pos - left_eye_x)/2;
                            face_top <= y_pos - (x_pos - left_eye_x)/2;
                        end
                    end
                end

                FIND_NOSE: begin
                    // Look for nose in expected region
                    if (x_pos >= left_eye_x && x_pos <= right_eye_x &&
                        y_pos >= left_eye_y + FEATURE_MIN_SIZE &&
                        y_pos <= left_eye_y + FEATURE_MAX_SIZE) begin
                        if (gray > NOSE_THRESHOLD) begin
                            nose_found <= 1;
                            nose_x <= x_pos;
                            nose_y <= y_pos;
                            state <= FIND_MOUTH;
                        end
                    end
                end

                FIND_MOUTH: begin
                    // Look for mouth below nose
                    if (x_pos >= nose_x - FEATURE_MAX_SIZE &&
                        x_pos <= nose_x + FEATURE_MAX_SIZE &&
                        y_pos >= nose_y + FEATURE_MIN_SIZE) begin
                        if (gray < MOUTH_THRESHOLD) begin
                            mouth_found <= 1;
                            mouth_x <= x_pos;
                            mouth_y <= y_pos;
                            face_bottom <= y_pos + FEATURE_MAX_SIZE;
                            state <= VERIFY;
                        end
                    end
                end

                VERIFY: begin
                    if (left_eye_found && right_eye_found && 
                        nose_found && mouth_found) begin
                        face_detected <= 1;
                        face_boundary_valid <= 1;
                        state <= DRAW;
                    end
                end

                DRAW: begin
                    // Draw green border
                    if (((x_pos >= face_left && x_pos <= face_left + BORDER_THICKNESS) ||
                         (x_pos <= face_right && x_pos >= face_right - BORDER_THICKNESS) ||
                         (y_pos >= face_top && y_pos <= face_top + BORDER_THICKNESS) ||
                         (y_pos <= face_bottom && y_pos >= face_bottom - BORDER_THICKNESS)) &&
                        (x_pos >= face_left && x_pos <= face_right) &&
                        (y_pos >= face_top && y_pos <= face_bottom)) begin
                        pixel_out <= 16'h07E0;  // Green color
                    end
                    else begin
                        pixel_out <= pixel_in;
                    end

                    // Reset at frame end
                    if (x_pos == IMG_WIDTH-1 && y_pos == IMG_HEIGHT-1) begin
                        state <= IDLE;
                        left_eye_found <= 0;
                        right_eye_found <= 0;
                        nose_found <= 0;
                        mouth_found <= 0;
                        face_boundary_valid <= 0;
                        face_detected <= 0;
                    end
                end
            endcase
        end
    end

endmodule