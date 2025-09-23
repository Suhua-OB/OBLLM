#!/usr/bin/env python3
"""
generate_tokenizer.py

Purpose:
    从模型目录生成标准的 tokenizer.json（供 Swift/MLX 使用）。

Usage:
    python generate_tokenizer.py /path/to/model_dir

Dependencies (建议在虚拟环境中安装):
    pip install transformers tokenizers

Notes:
  - 脚本会使用 transformers.AutoTokenizer (trust_remote_code=True) 来加载并保存 tokenizer.json。
"""
import sys
import os
from transformers import AutoTokenizer

def main(model_dir):
    model_dir = os.path.abspath(model_dir)

    if not os.path.isdir(model_dir):
        print(f"❌ 路径不是目录: {model_dir}")
        sys.exit(1)

    out_file = os.path.join(model_dir, "tokenizer.json")
    if os.path.exists(out_file):
        print(f"ℹ️ tokenizer.json 已存在: {out_file}")
        return

    print("⏳ 正在用 transformers.AutoTokenizer 生成 tokenizer.json ...")
    tok = AutoTokenizer.from_pretrained(model_dir, trust_remote_code=True, use_fast=True)
    tok.save_pretrained(model_dir, legacy_format=False)
    print(f"✅ 已生成: {out_file}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("用法: python generate_tokenizer.py /path/to/model_dir")
        print("依赖: pip install transformers tokenizers")
        sys.exit(1)
    main(sys.argv[1])
