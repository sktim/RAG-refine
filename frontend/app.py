import streamlit as st
import requests

# バックエンドのURL
BACKEND_URL = "http://backend:8000"

# Streamlitアプリのタイトル
st.title("Streamlit & FastAPI Integration")

# ユーザー入力を取得
input_text = st.text_input("Enter some text:")

if st.button("Submit"):
    # バックエンドにPOSTリクエストを送信
    try:
        response = requests.post(f"{BACKEND_URL}/process", json={"text": input_text})
        if response.status_code == 200:
            result = response.json()
            st.success(f"Processed Text: {result['processed_text']}")
        else:
            st.error(f"Error: {response.status_code}")
    except Exception as e:
        st.error(f"Failed to connect to backend: {e}")
