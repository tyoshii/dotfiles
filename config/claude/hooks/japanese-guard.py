#!/usr/bin/env python3
# ターンの最後の返答が英語の文章だったら、Stop をブロックして日本語で書き直させる。
# language 設定・CLAUDE.md・UserPromptSubmit のリマインドがあっても、長い作業の後は英語に戻りがちなため。
# コードブロック・インラインコード・URL・パスは除いてから、かな漢字と英字の量を比べる。
import json
import re
import sys

MIN_LETTERS = 60  # これより英字が少ない返答は判定しない（短い返答の誤検知よけ）
JP_RATIO = 0.1  # かな漢字の数が英字の数のこの割合未満なら英語とみなす

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# 書き直し後の Stop では止めない（無限ループ防止）
if data.get("stop_hook_active"):
    sys.exit(0)


def last_text(path):
    text = None
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                if e.get("type") != "assistant" or e.get("isSidechain"):
                    continue
                content = (e.get("message") or {}).get("content")
                if not isinstance(content, list):
                    continue
                texts = [c.get("text", "") for c in content if c.get("type") == "text"]
                if texts:
                    text = "\n".join(texts)
    except Exception:
        return None
    return text


text = data.get("last_assistant_message") or last_text(data.get("transcript_path", ""))
if not text:
    sys.exit(0)

body = re.sub(r"```.*?```", " ", text, flags=re.S)
body = re.sub(r"`[^`]*`", " ", body)
body = re.sub(r"https?://\S+", " ", body)
body = re.sub(r"[~./]?[\w.-]*/[\w./-]+", " ", body)

letters = len(re.findall(r"[A-Za-z]", body))
jp = len(re.findall(r"[぀-ヿ㐀-鿿]", body))

if letters < MIN_LETTERS or jp >= letters * JP_RATIO:
    sys.exit(0)

head = " ".join(text.split())[:60]
print(json.dumps({
    "decision": "block",
    "reason": (
        f"直前の返答が英語でした（「{head}…」）。返答・報告はすべて日本語で書く決まりです。"
        "同じ内容を日本語で書き直してください（作業のやり直しは不要）。この後の途中経過も日本語で書くこと。"
    ),
}, ensure_ascii=False))
