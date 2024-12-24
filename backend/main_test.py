from langchain_ollama.chat_models import ChatOllama
from langchain_ollama import OllamaLLM 

llm = ChatOllama(model="hf.co/elyza/Llama-3-ELYZA-JP-8B-GGUF", temperature=0.01)

answer = llm.invoke(("human", "transformerとは?")).content
print(type(answer)) 
print(answer)
