# 概要

ollmaを使って量子化したLLMを利用した環境

# この環境の目的
- API利用料なしにLLMを試す
- langchainやllamaindexなどのライブラリの実装確認をAPI利用料なしで利用可能
- ローカルLLMの精度の比較をする(現在この環境で利用可能なLLMは１つ)

# 環境についての留意点
- フロントとバックで異なるdockerfileを利用
- フロントはstremalitを利用しているがdockerfileを分けているので容易に別言語を採用できる
- formatter,linterにpysenを採用
- NvidiaのGPUが搭載されたPCが必要
- cudatoolkitが最新である必要がある
- cudatoolkit(https://www.scsk.jp/sp/nvidia/casestudy_column/column01.html)


# この環境で現在利用可能なLLM
llama-3-elyza-japanize
- metaのオープンなモデルであるllama3をelyzaが日本語で再学習したもの
- 商用利用可能
