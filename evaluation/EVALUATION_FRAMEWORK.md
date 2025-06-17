# 評価フレームワーク (`evaluation`) ドキュメント

このドキュメントは、HyperGraphRAG プロジェクトの `evaluation` ディレクトリに含まれる各ファイルの役割、主要なスクリプトや関数のロジック、およびそれらがどのように連携して評価パイプラインを形成するかについて説明します。

`evaluation` モジュールは、HyperGraphRAG システムの性能を多角的に評価し、他のRAG手法やベースラインと比較するためのツール群を提供します。

## 1. `README.md` (evaluation/README.md)

*   **役割**:
    評価フレームワークのセットアップ手順、依存関係、必要なデータセットの配置方法、および評価を実行するためのステップバイステップのガイドを提供します。評価プロセス全体の出発点となるドキュメントです。

## 2. `eval.py`

*   **役割**:
    Exact Match (EM) および F1 スコアという、質問応答タスクで一般的に用いられる正解率メトリクスを計算するための関数を提供します。
*   **主要な関数と処理内容**:
    *   `normalize_answer(answer: str) -> str`:
        *   処理内容: 回答文字列を正規化します。具体的には、小文字化、句読点除去、冠詞 ("a", "an", "the") 除去、連続する空白の単一化を行います。
        *   出力: 正規化された回答文字列。
    *   `calculate_metric_scores_em(gold_answers, predicted_answers, aggregation_fn)`:
        *   処理内容: 予測された回答と正解回答リスト（複数の正解がありうるためリスト形式）を比較し、EMスコアを計算します。`aggregation_fn` (通常は `np.max`) を用いて、複数の正解回答に対するEMスコアの中から最良のものを選択します。
        *   出力: プールされたEMスコアと、各サンプルごとのEMスコア。
    *   `calculate_metric_scores_f1(gold_answers, predicted_answers, aggregation_fn)`:
        *   処理内容: 予測された回答と正解回答リストを比較し、F1スコアを計算します。トークンベースで適合率 (Precision) と再現率 (Recall) を計算し、その調和平均としてF1スコアを算出します。同様に `aggregation_fn` を使用します。
        *   出力: プールされたF1スコアと、各サンプルごとのF1スコア。
    *   `cal_em(gold_answers, predicted_answers) -> float`:
        *   処理内容: `calculate_metric_scores_em` のラッパー関数。
        *   出力: 全体のEMスコア (float)。
    *   `cal_f1(gold_answers, predicted_answers) -> float`:
        *   処理内容: `calculate_metric_scores_f1` のラッパー関数。
        *   出力: 全体のF1スコア (float)。

## 3. `eval_r.py`

*   **役割**:
    R-Sim (Retrieval Similarity) スコアを計算するための機能を提供します。R-Sim は、検索された知識 (コンテキスト) が、正解の知識 (または質問に関連する理想的な知識) とどの程度意味的に類似しているかを評価する指標です。
*   **主要な関数と処理内容**:
    *   `SimCSE("princeton-nlp/sup-simcse-roberta-large")`:
        *   処理内容: `evaluation/simcse/tool.py` の `SimCSE` クラスを利用して、事前学習済みの SimCSE モデル (ここでは "princeton-nlp/sup-simcse-roberta-large") をロードします。このモデルがテキスト間の意味的類似度計算に使用されます。
    *   `normalize_answer(answer: str) -> str`: `eval.py` と同様の正規化関数。
    *   `calculate_metric_scores_rsim(gold_answers, predicted_answers)`:
        *   処理内容: 正解コンテキストリスト (`gold_answers`) と検索された知識リスト (`predicted_answers`) を受け取り、それぞれのペアに対して SimCSE モデルを用いてコサイン類似度を計算します。
        *   出力: プールされたR-Simスコア (平均類似度) と、各サンプルごとの類似度スコア。
    *   `cal_rsim(gold_answers, predicted_answers) -> float`:
        *   処理内容: `calculate_metric_scores_rsim` のラッパー関数。
        *   出力: 全体のR-Simスコア (float)。

## 4. `eval_g.py`

*   **役割**:
    Gen-Score (Generation Score) を計算するための機能を提供します。Gen-Score は、生成された回答の品質を、包括性、知識性、正確性、関連性、多様性、論理的一貫性、事実性といった複数の観点から、大規模言語モデル (LLM) を用いて評価する指標です。
*   **主要な関数と処理内容**:
    *   `OpenAI(api_key=..., base_url="https://api.apiyi.com/v1")`:
        *   処理内容: OpenAI の GPT モデル (具体的には "gpt-4o-mini") を評価者として利用するためにクライアントを初期化します。APIキーとカスタムベースURLが使用されます。
    *   `cal_gen(question, answers, generation, f1_score)`:
        *   処理内容:
            1.  評価対象の質問、正解回答リスト、生成された回答、および事前に計算されたF1スコアを受け取ります。
            2.  定義された各評価観点 (例: "comprehensiveness", "correctness") ごとに、質問、正解回答、生成回答を埋め込んだ専用のプロンプトを構築します。このプロンプトはLLMに対し、0-10の整数スケールで評価スコアとその理由を返すよう指示します。
            3.  各評価観点についてLLMを呼び出し、スコアと説明を取得します。
            4.  LLMから得られた各観点のスコア (0-10を0-1に正規化) と、入力されたF1スコアを平均します。
            5.  全観点での平均スコアを最終的な Gen-Score とします。
        *   出力: Gen-Score (float) と、各評価観点ごとのスコアおよびLLMによる説明を含む辞書。

## 5. `get_generation.py`

*   **役割**:
    `script_hypergraphrag.py` や `script_standardrag.py` などで準備された、質問とそれに対応する検索済み知識 (コンテキスト) のデータ (`test_knowledge.json`) を入力とし、LLM を用いて各質問に対する回答を生成するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数からデータソース (`data_sources`) と評価手法 (`methods`) を受け取ります。
    2.  指定された各手法・データソースの組み合わせについて、`results/{method}/{data_source}/test_knowledge.json` ファイルを読み込みます。
    3.  各データエントリ (質問と知識) について、知識と質問を埋め込んだプロンプトを作成します。プロンプトはLLMに対し、思考プロセスを `<think>...</think>` 内に、最終回答を `<answer>...</answer>` 内に出力するよう指示します。
    4.  OpenAI API (gpt-4o-mini) を使用して回答を非同期に生成します (`ThreadPoolExecutor` で並列処理)。
    5.  生成された回答、使用したプロンプトなどを元のデータエントリに追加し、`results/{method}/{data_source}/test_generation.json` に保存します。

## 6. `get_score.py`

*   **役割**:
    `get_generation.py` で生成された回答 (`test_generation.json`) を評価し、各種メトリクス (EM, F1, R-Sim, Gen-Score) を計算するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数から評価手法 (`method`) とデータソース (`data_source`) を受け取ります。
    2.  `results/{method}/{data_source}/test_generation.json` ファイルを読み込みます。
    3.  各データエントリについて、`evaluate_one` 関数を呼び出します (`ThreadPoolExecutor` で並列処理)。
        *   `evaluate_one` 関数内:
            *   生成回答から `<answer>...</answer>` タグ内のテキストを抽出。
            *   `eval.cal_em` と `eval.cal_f1` を用いてEMスコアとF1スコアを計算。
            *   `eval_r.cal_rsim` を用いてR-Simスコアを計算 (元のコンテキストと検索された知識を比較)。
            *   `eval_g.cal_gen` を用いてGen-Scoreとその説明を計算。
            *   計算された全スコアをデータエントリに追加。
    4.  全データエントリのスコアを集計し、平均EM、平均F1、平均R-Sim、平均Gen-Scoreを算出します。
    5.  詳細な結果 (各サンプルごとのスコア) を `results/{method}/{data_source}/test_result.json` に保存します。
    6.  集計された全体スコアを `results/{method}/{data_source}/test_score.json` に保存します。

## 7. `see_score.py`

*   **役割**:
    `get_score.py` で計算・保存された評価結果 (`test_score.json` と `test_result.json`) を読み込み、整形して表示するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数から評価手法 (`method`) とデータソース (`data_source`) を受け取ります。
    2.  対応する `test_score.json` (全体スコア) と `test_result.json` (詳細スコア) を読み込みます。
    3.  `test_result.json` のデータから、質問の特性 (`nary` フィールドに基づく二項関係の質問か多項関係の質問か) ごとにスコアを集計します (ただし、`nary` フィールドの出所は他のスクリプトでは明確ではありませんでした)。
    4.  集計されたスコアと全体スコアをコンソールに出力します。

## 8. `script_insert.py`

*   **役割**:
    指定されたカテゴリ (例: "hypertension") のコンテキストデータ (`contexts/{cls}_contexts.json`) を読み込み、`HyperGraphRAG` インスタンスを用いて知識ハイパーグラフを構築・保存するスクリプトです。評価の第一歩として、対象ドメインの知識ベースを作成します。
*   **スクリプトのロジック**:
    1.  コマンドライン引数からカテゴリ (`cls`) を受け取ります。
    2.  `HyperGraphRAG` インスタンスを初期化します (作業ディレクトリは `expr/{cls}` となります)。
    3.  `contexts/{cls}_contexts.json` からコンテキストデータをロードします。
    4.  `rag.insert(unique_contexts)` を呼び出して、データを処理し、知識ハイパーグラフを構築・永続化します。
    5.  挿入処理中にエラーが発生した場合のためのリトライロジックが含まれています。

## 9. `script_hypergraphrag.py`

*   **役割**:
    HyperGraphRAG を用いた評価のために、指定されたデータソースの質問集 (`datasets/{data_source}/questions.json`) に対して、関連知識 (コンテキスト) を検索するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数からデータソース (`data_source`) を受け取ります。
    2.  対応する作業ディレクトリ (`expr/{data_source}`) を指定して `HyperGraphRAG` インスタンスを初期化します。
    3.  `datasets/{data_source}/questions.json` から質問データをロードします。
    4.  各質問に対して `rag.aquery(question, QueryParam(only_need_context=True))` を非同期に実行し (`asyncio.Semaphore` で並列数を制限)、検索されたコンテキストのみを取得します。
    5.  質問と取得された知識をペアにして、`results/HyperGraphRAG/{data_source}/test_knowledge.json` に保存します。このファイルが `get_generation.py` の入力となります。

## 10. `script_naivegeneration.py`

*   **役割**:
    検索拡張なし (No Retrieval) のベースライン評価のために、質問データに対して空の知識コンテキストを持つファイル (`test_knowledge.json`) を準備するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数からデータソース (`data_source`) を受け取ります。
    2.  `datasets/{data_source}/questions.json` から質問データをロードします。
    3.  各質問に対して、`knowledge` フィールドを空文字列として設定します。
    4.  結果を `results/NaiveGeneration/{data_source}/test_knowledge.json` に保存します。

## 11. `script_standardrag.py`

*   **役割**:
    標準的なRAG (Standard RAG) のベースライン評価のために、`script_hypergraphrag.py` が生成した知識ファイルから、構造化されたエンティティやリレーション情報を除き、ソーステキストチャンクのみを知識コンテキストとして使用するようにファイルを準備するスクリプトです。
*   **スクリプトのロジック**:
    1.  コマンドライン引数からデータソース (`data_source`) を受け取ります。
    2.  `results/HyperGraphRAG/{data_source}/test_knowledge.json` (HyperGraphRAGが生成したコンテキストファイル) を読み込みます。
    3.  各データエントリの `knowledge` フィールドについて、`"-----Sources-----"` という区切り文字列より後の部分のみを抽出します。これにより、元のテキストチャンクのみがコンテキストとして残ります。
    4.  変更されたデータを `results/StandardRAG/{data_source}/test_knowledge.json` に保存します。

## 評価パイプライン (関連性)

`evaluation/README.md` に記載されている通り、これらのスクリプトは以下の順序で連携して動作します。

1.  **`script_insert.py`**: 対象ドメインの知識ハイパーグラフを構築。
2.  **知識検索スクリプト**:
    *   **`script_hypergraphrag.py`**: HyperGraphRAG を用いて知識を検索。
    *   **`script_standardrag.py`**: HyperGraphRAG の検索結果を加工し、標準RAG用の知識を準備。
    *   **`script_naivegeneration.py`**: 検索なし評価用の空の知識を準備。
    *   これらのスクリプトは、それぞれ `test_knowledge.json` を生成します。
3.  **`get_generation.py`**: 各手法の `test_knowledge.json` を入力とし、LLMで回答を生成し `test_generation.json` を作成。
4.  **`get_score.py`**: `test_generation.json` を入力とし、各種評価メトリクスを計算し `test_result.json` と `test_score.json` を作成。
5.  **`see_score.py`**: `test_score.json` と `test_result.json` を読み込んで結果を表示。

このパイプラインにより、HyperGraphRAG の性能を他の手法と比較し、詳細な分析を行うことができます。
