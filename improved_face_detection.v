module advanced_face_detection (
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg face_detected
);

    // Parameters for image and window sizes
    parameter IMG_WIDTH = 640;
    parameter IMG_HEIGHT = 480;
    parameter WIN_SIZE = 30;  // Minimum face window size
    parameter MAX_COMPONENTS = 5; // Maximum number of components to track

    // Parameters for skin detection in YCbCr space
    parameter [7:0] Y_MIN = 8'd60;
    parameter [7:0] Y_MAX = 8'd250;
    parameter [7:0] CB_MIN = 8'd85;
    parameter [7:0] CB_MAX = 8'd135;
    parameter [7:0] CR_MIN = 8'd135;
    parameter [7:0] CR_MAX = 8'd180;

    // Line buffers for window processing
    reg [7:0] line_buffer [0:IMG_WIDTH-1];
    reg [9:0] x_pos, y_pos;
    
    // Connected components tracking
    reg [9:0] comp_x [0:MAX_COMPONENTS-1];
    reg [9:0] comp_y [0:MAX_COMPONENTS-1];
    reg [9:0] comp_width [0:MAX_COMPONENTS-1];
    reg [9:0] comp_height [0:MAX_COMPONENTS-1];
    reg [2:0] comp_count;
    reg [3:0] curr_comp; // Current component being processed
    
    // Additional registers needed
    reg merged;
    reg is_face_pixel;
    
    // Color space conversion
    wire [7:0] Y, Cb, Cr;
    reg [7:0] r, g, b;
    
    // RGB565 to RGB888 conversion
    always @* begin
        r = {pixel_in[15:11], pixel_in[15:13]};
        g = {pixel_in[10:5], pixel_in[10:9]};
        b = {pixel_in[4:0], pixel_in[4:2]};
    end
    
    // RGB to YCbCr conversion
    assign Y  = ((r << 2) + (r << 1) + (g << 3) + g + (b << 2) + b) >> 4;
    assign Cb = 128 + ((-((r << 2) + (r << 1)) - (g << 2) - (g << 1) + (b << 3) + (b << 1)) >> 4);
    assign Cr = 128 + ((r << 3) + (r << 1) - (g << 2) - (g << 3) - (b << 1)) >> 4;

    // Skin detection function
    function is_skin;
        input [7:0] y, cb, cr;
        begin
            is_skin = (y >= Y_MIN && y <= Y_MAX &&
                      cb >= CB_MIN && cb <= CB_MAX &&
                      cr >= CR_MIN && cr <= CR_MAX);
        end
    endfunction

    // Component merging check
    function should_merge;
        input [9:0] x1, y1, w1, h1;
        input [9:0] x2, y2, w2, h2;
        reg overlap_x, overlap_y;
        begin
            overlap_x = (x1 + w1 >= x2) && (x2 + w2 >= x1);
            overlap_y = (y1 + h1 >= y2) && (y2 + h2 >= y1);
            should_merge = overlap_x && overlap_y;
        end
    endfunction

    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= 0;
            y_pos <= 0;
            face_detected <= 0;
            pixel_out <= 0;
            comp_count <= 0;
            curr_comp <= 0;
            merged <= 0;
            is_face_pixel <= 0;
        end
        else if (data_valid_in) begin
            // Update position counters
            if (x_pos == IMG_WIDTH-1) begin
                x_pos <= 0;
                y_pos <= (y_pos == IMG_HEIGHT-1) ? 0 : y_pos + 1;
            end
            else begin
                x_pos <= x_pos + 1;
            end

            // Reset processing flags
            merged <= 0;
            is_face_pixel <= 0;

            // Skin detection and component processing
            if (is_skin(Y, Cb, Cr)) begin
                // Process each component
                if (curr_comp < comp_count) begin
                    if (should_merge(comp_x[curr_comp], comp_y[curr_comp], 
                                   comp_width[curr_comp], comp_height[curr_comp],
                                   x_pos, y_pos, 1, 1)) begin
                        // Update component dimensions
                        if (x_pos < comp_x[curr_comp]) begin
                            comp_width[curr_comp] <= comp_width[curr_comp] + (comp_x[curr_comp] - x_pos);
                            comp_x[curr_comp] <= x_pos;
                        end
                        else if (x_pos > comp_x[curr_comp] + comp_width[curr_comp]) begin
                            comp_width[curr_comp] <= x_pos - comp_x[curr_comp];
                        end
                        
                        if (y_pos > comp_y[curr_comp] + comp_height[curr_comp]) begin
                            comp_height[curr_comp] <= y_pos - comp_y[curr_comp];
                        end
                        
                        merged <= 1;
                        
                        // Check if this component is face-sized
                        if (comp_width[curr_comp] >= WIN_SIZE && 
                            comp_height[curr_comp] >= WIN_SIZE) begin
                            is_face_pixel <= 1;
                        end
                    end
                    curr_comp <= curr_comp + 1;
                end
                else begin
                    curr_comp <= 0;
                    // Create new component if not merged and space available
                    if (!merged && comp_count < MAX_COMPONENTS) begin
                        comp_x[comp_count] <= x_pos;
                        comp_y[comp_count] <= y_pos;
                        comp_width[comp_count] <= 1;
                        comp_height[comp_count] <= 1;
                        comp_count <= comp_count + 1;
                    end
                end

                // Output face detection results
                if (is_face_pixel) begin
                    face_detected <= 1;
                    pixel_out <= 16'hF800; // Mark as red for visualization
                end
                else begin
                    face_detected <= 0;
                    pixel_out <= pixel_in;
                end
            end
            else begin
                curr_comp <= 0;
                face_detected <= 0;
                pixel_out <= pixel_in;
            end

            // Reset components at frame end
            if (x_pos == IMG_WIDTH-1 && y_pos == IMG_HEIGHT-1) begin
                comp_count <= 0;
                curr_comp <= 0;
            end
        end
    end

endmodule