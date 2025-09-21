#!/usr/bin/env python3
"""
generate_tokenizer.py

Purpose:
    从模型目录生成标准的 tokenizer.json（供 Swift/MLX 使用）。

Usage:
    python generate_tokenizer.py /path/to/model_dir

Dependencies (建议在虚拟环境中安装):
    pip install "transformers[torch]" tokenizers sentencepiece tiktoken

Notes:
  - 如果你使用的是 Python 3.13，注意 `tiktoken` 可能不支持该版本，建议使用 Python 3.11/3.10 的虚拟环境来运行该脚本。
  - 脚本会优先使用 transformers.AutoTokenizer (trust_remote_code=True) 来加载并保存 tokenizer.json。
  - 如果 AutoTokenizer 无法转换，但目录中有 vocab.json + merges.txt，会尝试用 tokenizers 库手动构造一个简化版的 tokenizer.json（适用于 GPT2-style BPE）。
"""

import sys
import os
import json
import traceback

def print_help_and_exit(msg=None):
    if msg:
        print(msg)
    print("\nUsage:\n  python generate_tokenizer.py /path/to/model_dir\n")
    print("Recommended installs (run in a virtualenv):")
    print("  python -m pip install --upgrade pip")
    print("  python -m pip install transformers tokenizers sentencepiece tiktoken")
    print("\nIf tiktoken fails to install on Python 3.13, try creating a Python 3.11 venv:")
    print("  pyenv install 3.11.6")
    print("  pyenv virtualenv 3.11.6 obllm-env")
    print("  pyenv activate obllm-env")
    print("  python -m pip install transformers tokenizers sentencepiece tiktoken")
    sys.exit(1)

def save_tokenizer_json_from_transformers(model_dir):
    """
    Try to load tokenizer via transformers.AutoTokenizer and save_pretrained.
    This is the preferred / easiest approach.
    """
    try:
        from transformers import AutoTokenizer
    except Exception as e:
        raise RuntimeError(f"transformers import failed: {e}")

    print("尝试用 transformers.AutoTokenizer.from_pretrained(..., trust_remote_code=True) 生成 tokenizer.json ...")
    try:
        tok = AutoTokenizer.from_pretrained(model_dir, trust_remote_code=True, use_fast=True)
        # save_pretrained will write tokenizer.json when using a fast tokenizer
        tok.save_pretrained(model_dir, legacy_format=False)
        print("✅ transformers 导出 tokenizer.json 成功")
        return True
    except Exception as e:
        # bubble up original error
        tb = traceback.format_exc()
        raise RuntimeError(f"AutoTokenizer failed: {e}\n{tb}")

def build_bpe_tokenizer_from_vocab_merges(model_dir, vocab_file, merges_file):
    """
    Try to construct a Tokenizer (tokenizers library) from vocab.json + merges.txt.
    This is a simplified construction for GPT2-style BPE tokenizers.
    """
    try:
        from tokenizers import Tokenizer, models, pre_tokenizers, decoders, processors, normalizers
    except Exception as e:
        raise RuntimeError(f"tokenizers import failed: {e}")

    print("尝试用 tokenizers 库基于 vocab.json + merges.txt 构造 tokenizer ...")
    try:
        with open(vocab_file, "r", encoding="utf-8") as f:
            vocab = json.load(f)
        # merges.txt sometimes has a header line; skip empty/comment lines
        merges = []
        with open(merges_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                # skip a possible header like "#version: 0.2"
                if line.startswith("#"):
                    continue
                merges.append(line)

        # tokenizers.models.BPE accepts merges as a list of pair strings like "a b"
        model = models.BPE(vocab=vocab, merges=merges)

        tokenizer = Tokenizer(model)

        # Typical GPT2 / byte-level BPE pipeline:
        try:
            tokenizer.normalizer = normalizers.Sequence([normalizers.NFC()])
        except Exception:
            # normalizer optional
            pass

        # ByteLevel pre-tokenizer is common for GPT2-style (merges from byte-level)
        try:
            tokenizer.pre_tokenizer = pre_tokenizers.ByteLevel(add_prefix_space=True)
            tokenizer.decoder = decoders.ByteLevel()
        except Exception:
            # fallback: use whitespace
            from tokenizers.pre_tokenizers import Whitespace
            tokenizer.pre_tokenizer = Whitespace()
            print("warning: ByteLevel pre_tokenizer 不可用，降级为 Whitespace")

        # If there is special_tokens files, add them
        special_tokens = []
        special_tokens_map = os.path.join(model_dir, "special_tokens_map.json")
        added_tokens = os.path.join(model_dir, "added_tokens.json")
        if os.path.exists(special_tokens_map):
            try:
                stm = json.load(open(special_tokens_map, "r", encoding="utf-8"))
                # stm is like {"unk_token":"<unk>", ...}
                for v in stm.values():
                    if isinstance(v, str):
                        special_tokens.append(v)
            except Exception:
                pass
        if os.path.exists(added_tokens):
            try:
                at = json.load(open(added_tokens, "r", encoding="utf-8"))
                # added_tokens might be list or dict
                if isinstance(at, list):
                    special_tokens.extend(at)
                elif isinstance(at, dict):
                    special_tokens.extend([x for x in at.keys()])
            except Exception:
                pass

        if special_tokens:
            # convert to the form [{"id":..., "special":...}, ...] is not needed here;
            # simply register as added tokens via tokenizer API
            try:
                tokenizer.add_special_tokens(special_tokens)
            except Exception:
                # older/newer API variations; ignore if not supported
                pass

        out_path = os.path.join(model_dir, "tokenizer.json")
        tokenizer.save(out_path)
        print(f"✅ 已生成简化的 tokenizer.json：{out_path}")
        return True
    except Exception as e:
        tb = traceback.format_exc()
        raise RuntimeError(f"手工构造 BPE tokenizer 失败: {e}\n{tb}")

def main(model_dir):
    model_dir = os.path.abspath(model_dir)
    if not os.path.isdir(model_dir):
        print(f"给定路径不是目录：{model_dir}")
        sys.exit(2)

    tokenizer_json = os.path.join(model_dir, "tokenizer.json")
    if os.path.exists(tokenizer_json):
        print(f"tokenizer.json 已存在：{tokenizer_json}（无需生成）")
        return

    # First: try using AutoTokenizer (best chance to handle custom tokenizers)
    try:
        if save_tokenizer_json_from_transformers(model_dir):
            return
    except Exception as e:
        err = str(e)
        print("AutoTokenizer 路径失败：")
        print(err)
        # If error mentions 'tiktoken' or 'SentencePiece', give clearer instructions
        if "tiktoken" in err:
            print("\n错误信息里提到缺少 `tiktoken`。请尝试运行：")
            print("  python -m pip install tiktoken")
            print("如果 pip 安装失败，考虑使用 Python 3.11 创建虚拟环境后再安装。")
        if "SentencePiece" in err or "sentencepiece" in err.lower():
            print("\n错误信息里提到缺少 SentencePiece 支持。请运行：")
            print("  python -m pip install sentencepiece")
        # continue to fallback attempts

    # Fallback: try constructing from vocab.json + merges.txt
    vocab_file = os.path.join(model_dir, "vocab.json")
    merges_file = os.path.join(model_dir, "merges.txt")
    if os.path.exists(vocab_file) and os.path.exists(merges_file):
        try:
            if build_bpe_tokenizer_from_vocab_merges(model_dir, vocab_file, merges_file):
                return
        except Exception as e:
            print("手工构造 BPE tokenizer 失败：")
            print(e)

    # If we reach here, we couldn't generate tokenizer.json
    print("\n❌ 无法自动生成 tokenizer.json。建议：")
    print("  1) 在 Python 虚拟环境中安装依赖并重试：")
    print("       python -m pip install --upgrade pip")
    print("       python -m pip install transformers tokenizers sentencepiece tiktoken")
    print("  2) 或者在 Python 中手动导出（推荐）：")
    print("       from transformers import AutoTokenizer")
    print("       tok = AutoTokenizer.from_pretrained('/path/to/model', trust_remote_code=True, use_fast=True)")
    print("       tok.save_pretrained('/path/to/model', legacy_format=False)")
    print("  3) 如果模型依赖私有 tokenizer（trust_remote_code=True 仍失败），请检查模型作者的说明或在支持的 Python 版本（如 3.11）下运行。")
    sys.exit(3)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print_help_and_exit()
    main(sys.argv[1])