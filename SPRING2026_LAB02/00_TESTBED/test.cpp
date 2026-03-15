#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include "isp_model.hpp"

bool read_hex_file(const std::string& filename, std::vector<int>& data) {
    std::ifstream fin(filename);
    if (!fin) return false;
    std::string token;
    while (fin >> token) {
        // 略過註解行
        if (token.find("//") == 0) {
            std::string line;
            std::getline(fin, line);
            continue;
        }
        try { data.push_back(std::stoi(token, nullptr, 16)); } catch (...) {}
    }
    return true;
}

int main() {
    // 1. 讀取輸入影像
    std::vector<int> in_data;
    if (!read_hex_file("input.txt", in_data) || in_data.size() < 256) {
        std::cerr << "Failed to read input.txt or data missing.\n";
        return 1;
    }
    in_data.resize(256);

    // 2. 讀取 LSC Gain Map
    std::vector<int> gain_data;
    if (!read_hex_file("lsc_gain_map.txt", gain_data) || gain_data.size() < 144) {
        std::cerr << "Failed to read lsc_gain_map.txt or data missing.\n";
        return 1;
    }

    ISP_Model isp;
    
    // 3. 將 Gain 寫入 C++ Model 的 Buffer
    // 根據硬體 Shift Register 推入順序：
    // 最先讀進來的值會被擠到 k=3, i=0, j=0。
    // (模型中 c=3 為 R, c=2 為 Gr, c=1 為 Gb, c=0 為 B)
    int idx = 0;
    for (int c = 3; c >= 0; --c) {
        for (int i = 0; i < 6; ++i) {
            for (int j = 0; j < 6; ++j) {
                isp.gain_buf[c][i][j] = gain_data[idx++];
            }
        }
    }

    // 4. 執行模型運算
    std::vector<int> out_r, out_g, out_b;
    isp.process(in_data, out_r, out_g, out_b);

    // 5. 讀取助教的 Golden 檔進行比對
    std::vector<int> gold_r, gold_g, gold_b;
    read_hex_file("output_r_ccm.txt", gold_r);
    read_hex_file("output_g_ccm.txt", gold_g);
    read_hex_file("output_b_ccm.txt", gold_b);

    bool pass = true;
    for (int i = 0; i < 256; ++i) {
        if (!gold_r.empty() && out_r[i] != gold_r[i]) {
            std::cout << "Mismatch R at idx " << i << ": Exp " << std::hex << gold_r[i] << " Got " << out_r[i] << "\n";
            pass = false;
        }
        if (!gold_g.empty() && out_g[i] != gold_g[i]) {
            std::cout << "Mismatch G at idx " << i << ": Exp " << std::hex << gold_g[i] << " Got " << out_g[i] << "\n";
            pass = false;
        }
        if (!gold_b.empty() && out_b[i] != gold_b[i]) {
            std::cout << "Mismatch B at idx " << i << ": Exp " << std::hex << gold_b[i] << " Got " << out_b[i] << "\n";
            pass = false;
        }
    }

    if (pass) {
        std::cout << "\n[TEST PASSED] C++ Model exactly matches TA's Golden files with LSC gains!\n";
    } else {
        std::cout << "\n[TEST FAILED] Mismatch detected.\n";
    }
    
    return 0;
}