module enhanced_skin_detection(
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg skin_detected
);

    // RGB565 to RGB888 conversion
    wire [7:0] r8 = {pixel_in[15:11], pixel_in[15:13]};
    wire [7:0] g8 = {pixel_in[10:5], pixel_in[10:9]};
    wire [7:0] b8 = {pixel_in[4:0], pixel_in[4:2]};

    // YCbCr conversion (fixed-point calculations)
    wire [15:0] Y  = ((77 * r8 + 150 * g8 + 29 * b8) >> 8);
    wire [15:0] Cb = (((-43 * r8 - 85 * g8 + 128 * b8) >> 8) + 128);
    wire [15:0] Cr = (((128 * r8 - 107 * g8 - 21 * b8) >> 8) + 128);

    // HSV conversion helpers
    wire [7:0] max_rgb = (r8 > g8) ? ((r8 > b8) ? r8 : b8) : ((g8 > b8) ? g8 : b8);
    wire [7:0] min_rgb = (r8 < g8) ? ((r8 < b8) ? r8 : b8) : ((g8 < b8) ? g8 : b8);
    wire [7:0] delta = max_rgb - min_rgb;

    // Saturation calculation
    wire [7:0] S = (max_rgb != 0) ? ((delta * 255) / max_rgb) : 8'h00;

    // RGB ratio check
    wire rgb_rule1 = (r8 > g8) && (g8 > b8);
    wire rgb_rule2 = (r8 - g8) > 20;  // Strong red component

    // YCbCr rules for skin detection
    wire ycbcr_rule = (Y > 80) && (Y < 240) &&     // Good brightness range
                      (Cb > 77) && (Cb < 127) &&    // Typical skin Cb range
                      (Cr > 133) && (Cr < 173);     // Typical skin Cr range

    // Additional rules for better accuracy
    wire sat_rule = (S > 20) && (S < 180);    // Not too saturated, not too gray
    wire rgb_dist_rule = (max_rgb - min_rgb) > 15;  // Good color distinction

    // Sliding window for temporal smoothing
    reg [2:0] detection_history;
    wire majority_vote = (detection_history[0] + detection_history[1] + detection_history[2]) >= 2;

    // Enhanced skin detection logic
    wire is_skin = rgb_rule1 && rgb_rule2 && ycbcr_rule && sat_rule && rgb_dist_rule;

    // Registers for region growing
    reg [9:0] skin_region_size;
    parameter MIN_REGION_SIZE = 50;
    reg in_skin_region;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 0;
            skin_detected <= 0;
            detection_history <= 0;
            skin_region_size <= 0;
            in_skin_region <= 0;
        end
        else if (data_valid_in) begin
            // Update detection history
            detection_history <= {detection_history[1:0], is_skin};

            // Region growing logic
            if (is_skin) begin
                if (in_skin_region) begin
                    if (skin_region_size < 1023)
                        skin_region_size <= skin_region_size + 1;
                end
                else begin
                    in_skin_region <= 1;
                    skin_region_size <= 1;
                end
            end
            else begin
                if (skin_region_size < MIN_REGION_SIZE) begin
                    in_skin_region <= 0;
                    skin_region_size <= 0;
                end
            end

            // Final decision based on multiple factors
            if (majority_vote && in_skin_region && (skin_region_size >= MIN_REGION_SIZE)) begin
                skin_detected <= 1;
                // Highlight skin with a slight red tint while preserving original features
                pixel_out <= {
                    pixel_in[15:11] | 5'b10000,  // Enhance red
                    pixel_in[10:5],              // Preserve green
                    pixel_in[4:0]                // Preserve blue
                };
            end
            else begin
                skin_detected <= 0;
                pixel_out <= pixel_in;
            end
        end
    end

endmodule