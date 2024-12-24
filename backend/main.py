from fastapi import FastAPI
from pydantic import BaseModel
from langchain_ollama.chat_models import ChatOllama

llm = ChatOllama(model="hf.co/elyza/Llama-3-ELYZA-JP-8B-GGUF", temperature=0.01)

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
    answer = llm.invoke(("human",processed_text)).content
    #response = model.invoke(input=processed_text) 
    return {"processed_text": answer}
    # return {"AI": response}
