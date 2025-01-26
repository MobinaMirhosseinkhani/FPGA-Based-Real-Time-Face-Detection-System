module vga_interface(
    input wire clk, rst_n,
    // asyn_fifo IO
    input wire empty_fifo,
    input wire [15:0] din,
    output wire clk_vga,
    output reg rd_en,
    // VGA output
    output reg [4:0] vga_out_r,
    output reg [5:0] vga_out_g,
    output reg [4:0] vga_out_b,
    output wire vga_out_vs, vga_out_hs,
    // Face detection coordinates
    input wire [11:0] face_x, face_y, face_width, face_height
);

    // FSM state declarations
    localparam delay = 0,
               idle = 1,
               display = 2;

    reg [1:0] state_q, state_d;
    wire [11:0] pixel_x, pixel_y;

    // Calculate rectangle coordinates around the face
    wire [11:0] rect_x1 = face_x - 10; // 10 pixels margin around the face
    wire [11:0] rect_y1 = face_y - 10;
    wire [11:0] rect_x2 = face_x + face_width + 10;
    wire [11:0] rect_y2 = face_y + face_height + 10;

    // Register operations
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state_q <= delay;
        end else begin
            state_q <= state_d;
        end
    end

    // FSM next-state logic
    always @* begin
        state_d = state_q;
        rd_en = 0;
        vga_out_r = 0;
        vga_out_g = 0;
        vga_out_b = 0;

        case(state_q)
            delay: if (pixel_x == 1 && pixel_y == 1) state_d = idle;
            idle:  if (pixel_x == 1 && pixel_y == 0 && !empty_fifo) begin
                       // Check if the current pixel is within the rectangle around the face
                       if ((pixel_x >= rect_x1 && pixel_x <= rect_x2) && 
                           (pixel_y >= rect_y1 && pixel_y <= rect_y2)) begin
                           // Draw green rectangle
                           vga_out_r = 5'b00000;  // Red component off
                           vga_out_g = 6'b111111; // Green component max
                           vga_out_b = 5'b00000;  // Blue component off
                       end else begin
                           // Normal pixel data
                           vga_out_r = din[15:11];
                           vga_out_g = din[10:5];
                           vga_out_b = din[4:0];
                       end
                       rd_en = 1;
                       state_d = display;
                   end
            display: if (pixel_x >= 1 && pixel_x <= 640 && pixel_y < 480) begin
                         // Check if the current pixel is within the rectangle around the face
                         if ((pixel_x >= rect_x1 && pixel_x <= rect_x2) && 
                             (pixel_y >= rect_y1 && pixel_y <= rect_y2)) begin
                             // Draw green rectangle
                             vga_out_r = 5'b00000;  // Red component off
                             vga_out_g = 6'b111111; // Green component max
                             vga_out_b = 5'b00000;  // Blue component off
                         end else begin
                             // Normal pixel data
                             vga_out_r = din[15:11];
                             vga_out_g = din[10:5];
                             vga_out_b = din[4:0];
                         end
                         rd_en = 1;
                     end
            default: state_d = delay;
        endcase
    end

    assign clk_vga = clk_out;

    // Module instantiations
    vga_core m0 (
        .clk(clk_out),
        .rst_n(rst_n),
        .hsync(vga_out_hs),
        .vsync(vga_out_vs),
        .video_on(),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    dcm_25MHz m1 (
        .clk(clk),
        .clk_out(clk_out),
        .RESET(~rst_n),
        .LOCKED()
    );

endmodule