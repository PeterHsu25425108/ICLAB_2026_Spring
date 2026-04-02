import numpy as np
import os
import shutil
# ===================================================================
# Configuration
# ===================================================================
PATNUM = 10
OUT_DIR = "../00_TESTBED/"
INTER_OUT_DIR = "inter_out"

# ===================================================================
# Helper Functions
# ===================================================================
def create_dir_if_not_exists(path):
    if not os.path.exists(path):
        os.makedirs(path)

def write_hex_file(filepath, data_list, bits):
    fmt = f"0{bits//4}X"
    with open(filepath, 'w') as f:
        for val in data_list:
            mask = (1 << bits) - 1
            masked_val = int(val) & mask
            f.write(f"{masked_val:{fmt}}\n")

def save_inter_data(base_dir, stage_name, iteration, data):
    stage_dir = os.path.join(base_dir, stage_name)
    create_dir_if_not_exists(stage_dir)
    filepath = os.path.join(stage_dir, f"{stage_name}_{iteration}.txt")
    np.savetxt(filepath, data.flatten(), fmt='%d')

def conv2d(img, weight, stride):
    in_h, in_w, in_c = img.shape
    out_c = weight.shape[0]
    
    out_h = (in_h + 2 * 1 - 3) // stride + 1
    out_w = (in_w + 2 * 1 - 3) // stride + 1
    
    out = np.zeros((out_h, out_w, out_c), dtype=np.int32)
    pad_img = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='constant', constant_values=0)
    
    for oc in range(out_c):
        for ic in range(in_c):
            for y in range(out_h):
                for x in range(out_w):
                    y_start = y * stride
                    x_start = x * stride
                    window = pad_img[y_start:y_start+3, x_start:x_start+3, ic]
                    out[y, x, oc] += np.sum(window * weight[oc, ic])
                    
    out = (out >> 6) + 128
    out = np.clip(out, 0, 255)
    return out

def transformer_block(feat, w_q, w_k, w_v, w_ffn, trans_dir, iteration):
    feat_flat = feat.reshape(256, 16).astype(np.int32)
    
    # 1. - Mid point
    calc_val = feat_flat - 128
    save_inter_data(trans_dir, "mid_point", iteration, calc_val)
    
    # 2. Linear Transformation -> Norm + Clip
    Q = np.clip((calc_val @ w_q) >> 4, -128, 127)
    K = np.clip((calc_val @ w_k) >> 4, -128, 127)
    V = np.clip((calc_val @ w_v) >> 4, -128, 127)
    save_inter_data(trans_dir, "q", iteration, Q)
    save_inter_data(trans_dir, "k", iteration, K)
    save_inter_data(trans_dir, "v", iteration, V)
    
    # 3. Softmax (QK^T / sqrt(d))
    attn = Q @ K.T
    attn = attn >> 2 
    attn = np.clip(attn, -2048, 2047)
    
    fixpoint = np.clip((attn >> 4) + 128, 0, 255)
    save_inter_data(trans_dir, "softmax", iteration, fixpoint)
    
    # 4. MatMul -> Norm + Clip
    context = fixpoint @ V
    context = np.clip(context >> 16, -128, 127)
    save_inter_data(trans_dir, "attn_out", iteration, context)
    
    # 5. FFN Linear Transformation
    ffn_linear = context @ w_ffn
    save_inter_data(trans_dir, "ffn_linear", iteration, ffn_linear)
    
    # 6. FFN Normalization -> ReLU + Clip
    ffn_out = np.clip((ffn_linear >> 4) + 128, 0, 255)
    out_reshaped = ffn_out.reshape(16, 16, 16)
    save_inter_data(trans_dir, "ffn_out", iteration, out_reshaped)
    
    return out_reshaped

def interpolate(feat, mode):
    feat_2d = feat.reshape(16, 16).astype(np.int32)
    out = np.zeros((64, 64), dtype=np.int32)
    
    if mode == 0:
        for y in range(16):
            for x in range(16):
                out[y*4:(y+1)*4, x*4:(x+1)*4] = feat_2d[y, x]
                
    elif mode == 1:
        out_h = np.zeros((16, 64), dtype=np.int32)
        for y in range(16):
            for x in range(15):
                step = (feat_2d[y, x+1] - feat_2d[y, x]) >> 2
                for i in range(4):
                    out_h[y, x*4 + i] = feat_2d[y, x] + i * step
            
            step = (feat_2d[y, 15] - feat_2d[y, 14]) >> 2
            for i in range(4):
                out_h[y, 60 + i] = feat_2d[y, 15] + i * step
                
        out_h = np.clip(out_h, 0, 255)
        
        for y in range(16):
            out[y*4:(y+1)*4, :] = out_h[y:y+1, :]
            
    elif mode == 2:
        out_v = np.zeros((64, 16), dtype=np.int32)
        for x in range(16):
            for y in range(15):
                step = (feat_2d[y+1, x] - feat_2d[y, x]) >> 2
                for i in range(4):
                    out_v[y*4 + i, x] = feat_2d[y, x] + i * step
            
            step = (feat_2d[15, x] - feat_2d[14, x]) >> 2
            for i in range(4):
                out_v[60 + i, x] = feat_2d[15, x] + i * step
                
        out_v = np.clip(out_v, 0, 255)
        
        for x in range(16):
            out[:, x*4:(x+1)*4] = out_v[:, x:x+1]
            
    return np.clip(out, 0, 255).reshape(64, 64, 1)

# ===================================================================
# Main Generation Process
# ===================================================================
def main():
    # Clear the intermediate output directory if it exists
    # if os.path.exists(INTER_OUT_DIR):
    #     shutil.rmtree(INTER_OUT_DIR)
    #     print("Cleared existing intermediate output directory.")
        
    create_dir_if_not_exists(OUT_DIR)
    create_dir_if_not_exists(INTER_OUT_DIR)
    
    w_conv1 = np.random.randint(-8, 8, size=(16, 1, 3, 3), dtype=np.int32)
    w_q = np.random.randint(-8, 8, size=(16, 16), dtype=np.int32)
    w_k = np.random.randint(-8, 8, size=(16, 16), dtype=np.int32)
    w_v = np.random.randint(-8, 8, size=(16, 16), dtype=np.int32)
    w_ffn = np.random.randint(-8, 8, size=(16, 16), dtype=np.int32)
    w_conv2 = np.random.randint(-8, 8, size=(1, 16, 3, 3), dtype=np.int32)
    
    all_weights = np.concatenate([
        w_conv1.flatten(),
        w_q.flatten(),
        w_k.flatten(),
        w_v.flatten(),
        w_ffn.flatten(),
        w_conv2.flatten()
    ])
    write_hex_file(os.path.join(OUT_DIR, "input_weight.txt"), all_weights, bits=4)
    
    all_images = []
    all_iters = []
    all_modes = []
    all_golden = []
    
    for pat in range(PATNUM):
        initial_img = np.random.randint(0, 256, size=(64, 64, 1), dtype=np.int32)
        iter_count = np.random.randint(1, 8) 
        mode_val = np.random.randint(0, 3)   
        
        all_images.extend(initial_img.flatten())
        all_iters.append(iter_count)
        all_modes.append(mode_val)
        
        current_img = np.copy(initial_img)
        
        pat_dir = os.path.join(INTER_OUT_DIR, f"pat{pat}")
        create_dir_if_not_exists(pat_dir)
        
        trans_dir = os.path.join(pat_dir, "transformer")
        create_dir_if_not_exists(trans_dir)
        
        for it in range(iter_count):
            conv1_out = conv2d(current_img, w_conv1, stride=4)
            save_inter_data(pat_dir, "conv1", it, conv1_out)
            
            trans_out = transformer_block(conv1_out, w_q, w_k, w_v, w_ffn, trans_dir, it)
            
            conv2_out = conv2d(trans_out, w_conv2, stride=1)
            save_inter_data(pat_dir, "conv2", it, conv2_out)
            
            interp_out = interpolate(conv2_out, mode_val)
            save_inter_data(pat_dir, "interp", it, interp_out)
            
            scaled_noise = interp_out >> 3
            current_img = np.clip(current_img - scaled_noise, 0, 255)
            save_inter_data(pat_dir, "denoise", it, current_img)
            
        all_golden.extend(current_img.flatten())
        print(f"Pattern {pat+1}/{PATNUM} generated.")

    write_hex_file(os.path.join(OUT_DIR, "input_image.txt"), all_images, bits=8)
    write_hex_file(os.path.join(OUT_DIR, "input_iter.txt"), all_iters, bits=4) 
    write_hex_file(os.path.join(OUT_DIR, "input_mode.txt"), all_modes, bits=4) 
    write_hex_file(os.path.join(OUT_DIR, "golden_output.txt"), all_golden, bits=8)

    print("All files successfully generated.")

if __name__ == "__main__":
    main()