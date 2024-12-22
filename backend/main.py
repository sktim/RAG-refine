# from langmodel import llm

# llm.nvoke(("human","LLMについて教えてください。")).content

from fastapi import FastAPI
from pydantic import BaseModel

# 入力データのスキーマ
class InputData(BaseModel):
    text: str

# 出力データのスキーマ
class OutputData(BaseModel):
    processed_text: str

# FastAPIアプリケーション
app = FastAPI()

@app.post("/process", response_model=OutputData)
async def process_text(data: InputData):
    # 入力データを加工するロジック（ここでは簡単な例としてテキストを大文字に変換）
    processed_text = data.text.upper()
    return {"processed_text": processed_text}
