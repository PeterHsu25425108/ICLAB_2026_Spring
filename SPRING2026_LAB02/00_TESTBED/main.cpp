#include <iostream>
#include <fstream>
#include <iomanip>
#include <vector>
#include <string>
#include <random>
#include <sys/stat.h> // 替換 filesystem，用來建立資料夾
#include <sys/types.h>
#include "isp_model.hpp"

// 將一筆 Pattern 的資料寫入已經開啟的檔案中
// cols 用來控制每行印幾個數字 (影像為 16, Gain Map 為 6)
void write_pattern_block(std::ofstream& fout, const std::vector<int>& data, int pat_idx, int cols) {
    fout << "// Pattern " << std::setfill('0') << std::setw(3) << std::dec << pat_idx << "\n";
    for (size_t i = 0; i < data.size(); ++i) {
        fout << std::setw(3) << std::setfill('0') << std::hex << std::uppercase << data[i];
        if ((i + 1) % cols == 0) fout << "\n";
        else fout << " ";
    }
}

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <PAT_NUM> <CORNER_PERCENT> <CASE_NAME>\n";
        return 1;
    }

    int pat_num = std::stoi(argv[1]);
    int corner_percent = std::stoi(argv[2]);
    std::string case_name = argv[3];

    // 防呆處理
    if (corner_percent > 100) {
        std::cerr << "[WARNING] CORNER_PERCENT > 100. Capping at 100.\n";
        corner_percent = 100;
    } else if (corner_percent < 0) corner_percent = 0;

    // 建立資料夾
    mkdir(case_name.c_str(), 0777);

    // 開啟 5 個輸出檔案
    std::ofstream f_in(case_name + "/input.txt");
    std::ofstream f_gain(case_name + "/lsc_gain_map.txt");
    std::ofstream f_r(case_name + "/output_r_ccm.txt");
    std::ofstream f_g(case_name + "/output_g_ccm.txt");
    std::ofstream f_b(case_name + "/output_b_ccm.txt");

    // 寫入檔案標頭 (Global Headers)
    f_in   << "// DPC Input (RAW 12-bit HEX) [Sensor RAW = shaded + BLC offset + Defects]\n";
    f_gain << "// LSC Param Gain (single 144-value map, stream order R, Gr, Gb, B)\n";
    f_r    << "// After DPC + Demosaic + CCM - R\n";
    f_g    << "// After DPC + Demosaic + CCM - G\n";
    f_b    << "// After DPC + Demosaic + CCM - B\n";

    std::mt19937 gen(1234); // 設定 Seed
    // Normal Range: 0 ~ 4095
    // Corner Range: 最大值的 90% 以內 (3686 ~ 4095)
    std::uniform_int_distribution<> dist_std(0, 4095);
    std::uniform_int_distribution<> dist_corner(3686, 4095);

    int corner_count = 0;

    // PATTERN.v 只會在 patcount==0 時送一次 gain (send_gain_once)，
    // 因此 main.cpp 需固定一份 gain 給所有 pattern，才能與 RTL 行為一致。
    ISP_Model isp;
    std::vector<int> gains(144);
    for (int c = 0; c < 4; ++c) {
        for (int i = 0; i < 6; ++i) {
            for (int j = 0; j < 6; ++j) {
                int g = dist_std(gen);
                isp.gain_buf[c][i][j] = g;
                // 串流順序需為 ch 3,2,1,0 (R, Gr, Gb, B)
                gains[(3 - c) * 36 + i * 6 + j] = g;
            }
        }
    }
    write_pattern_block(f_gain, gains, 1, 6);

    for (int p = 1; p <= pat_num; ++p) {
        bool is_corner = (gen() % 100) < corner_percent;
        if (is_corner) corner_count++;

        // 1. 生成輸入影像資料 (256 pixels)
        std::vector<int> in_data(256);
        for (int i = 0; i < 256; ++i) in_data[i] = is_corner ? dist_corner(gen) : dist_std(gen);

        // 3. 呼叫 C++ Model 計算結果
        std::vector<int> out_r, out_g, out_b;
        isp.process(in_data, out_r, out_g, out_b);

        // 4. 將這筆 Pattern 的資料附加寫入對應的檔案
        write_pattern_block(f_in,   in_data, p, 16);
        write_pattern_block(f_r,    out_r,   p, 16);
        write_pattern_block(f_g,    out_g,   p, 16);
        write_pattern_block(f_b,    out_b,   p, 16);
    }

    // 關閉檔案
    f_in.close(); f_gain.close(); f_r.close(); f_g.close(); f_b.close();

    std::cout << "[SUCCESS] Generated " << pat_num << " patterns inside directory './" << case_name << "'.\n";
    std::cout << "[INFO] Actual corner cases generated: " << corner_count << " (" 
              << (corner_count * 100 / pat_num) << "%).\n";
    return 0;
}