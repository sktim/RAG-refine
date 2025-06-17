# `evaluation/simcse` サブモジュール ドキュメント

このドキュメントは、`evaluation` モジュール内の `simcse` サブモジュールの役割と、その構成ファイルについて説明します。

`simcse` サブモジュールは、SimCSE (Simple Contrastive Learning of Sentence Embeddings) に関連する機能を提供します。HyperGraphRAG の評価フレームワーク内では、主に `eval_r.py` がこのサブモジュールの `SimCSE` クラスを利用して、検索された知識と正解コンテキスト間の意味的類似度 (R-Sim スコア) を計算するために使用されます。

サブモジュールには、SimCSEモデルの定義、SimCSEモデルを扱うためのツールクラス、およびSimCSEモデルを訓練するためのカスタムトレーナが含まれていますが、評価においては主に事前学習済みモデルを利用した類似度計算が中心となります。

## 1. `__init__.py`

*   **役割**:
    `evaluation/simcse` ディレクトリを Python のサブパッケージとして認識させるための標準的なファイルです。
*   **処理内容**:
    `from .tool import SimCSE` という記述により、`tool.py` 内で定義されている `SimCSE` クラスをサブモジュールのトップレベルからインポート可能にしています。これにより、他のスクリプト (例: `eval_r.py`) は `from simcse import SimCSE` のようにしてこのクラスを利用できます。

## 2. `models.py`

*   **役割**:
    SimCSE のための PyTorch モデル (`BertForCL`, `RobertaForCL`) を定義しています。これらは Hugging Face Transformers の `BertPreTrainedModel` および `RobertaPreTrainedModel` をベースとしており、対照学習 (Contrastive Learning) を行うための変更が加えられています。
*   **主要なクラスと機能**:
    *   `MLPLayer`: TransformerモデルのCLSトークン表現の上に適用される多層パーセプトロン (MLP) レイヤー。対照学習において、表現を射影するために使われることがあります。
    *   `Similarity`: 2つのベクトル間のコサイン類似度を計算するモジュール。温度パラメータ (temp) を用いて類似度スコアをスケーリングします。
    *   `Pooler`: Transformerモデルの出力から文全体の埋め込みベクトルを生成するための様々なプーリング戦略 (例: CLSトークンを使用、最終層の平均プーリングなど) を提供します。
    *   `BertForCL(BertPreTrainedModel)` / `RobertaForCL(RobertaPreTrainedModel)`:
        *   処理内容: SimCSEの学習および推論のためのモデル構造を定義します。
        *   `cl_init()`: 対照学習に必要なコンポーネント (上記 `Pooler`, `MLP`, `Similarity`) を初期化します。
        *   `cl_forward()`: 対照学習のフォワードパスを実装します。入力バッチ (通常、正例ペアやハードネガティブを含むトリプレット) からそれぞれの埋め込みを計算し、それらの間の類似度を算出し、対照学習の損失 (通常は InfoNCE 損失) を計算します。オプションで、Masked Language Modeling (MLM) の補助的な損失も計算に含めることができます。分散学習時の勾配集約も考慮されています。
        *   `sentemb_forward()`: 文埋め込みを生成するためのフォワードパス。学習済みモデルを用いて入力文の埋め込みベクトルを計算します。
*   **評価フレームワークでの利用**:
    `eval_r.py` では、このファイルで定義されるモデル構造を直接利用するのではなく、これらのモデル構造で学習された事前学習済み SimCSE モデル (例: "princeton-nlp/sup-simcse-roberta-large") を `tool.py` の `SimCSE` クラスを通じて利用します。

## 3. `tool.py`

*   **役割**:
    事前学習済みの SimCSE モデルをロードし、文のエンコード、文ペア間の類似度計算、および文のインデックス構築と検索を行うための高レベルなインターフェース `SimCSE` クラスを提供します。
*   **`SimCSE` クラスの主要なメソッドと処理内容**:
    *   `__init__(model_name_or_path: str, ...)`:
        *   処理内容: 指定されたモデル名またはパスから、Hugging Face Transformers の `AutoModel` と `AutoTokenizer` を用いて SimCSE モデルとトークナイザをロードします。使用するデバイス (CPU/GPU) やプーリング戦略も設定します。
        *   出力: 初期化された `SimCSE` インスタンス。
    *   `encode(sentence: Union[str, List[str]], ...)`:
        *   処理内容: 単一または複数の入力文を受け取り、ロードされた SimCSE モデルとトークナイザを用いて文埋め込みベクトルを生成します。バッチ処理、パディング、切り捨て、デバイス指定、正規化 (単位ベクトル化) などのオプションがあります。
        *   出力: 文埋め込みベクトル (PyTorch Tensor または NumPy配列)。
    *   `similarity(queries: Union[str, List[str]], keys: Union[str, List[str], ndarray], ...)`:
        *   処理内容: 1つ以上のクエリ文と、1つ以上のキー文 (または事前に計算されたキー埋め込み) を受け取ります。`encode` メソッドでそれぞれの埋め込みベクトルを計算し、それらの間のコサイン類似度を計算します。
        *   出力: クエリとキー間の類似度スコア (単一のfloat値またはNumPy配列)。
    *   `build_index(sentences_or_file_path: Union[str, List[str]], use_faiss: bool = None, ...)`:
        *   処理内容: 大量の文のリスト (または文を含むファイルパス) を受け取り、それらの埋め込みベクトルを計算し、検索用のインデックスを構築します。`use_faiss` が True で Faiss ライブラリが利用可能な場合、効率的な近似最近傍探索のための Faiss インデックスを構築します。そうでない場合は、NumPy 配列として全埋め込みを保持し、ブルートフォース検索を行います。
        *   出力: なし (インスタンス内部にインデックスが構築される)。
    *   `add_to_index(sentences_or_file_path: Union[str, List[str]], ...)`:
        *   処理内容: 既存のインデックスに新しい文とその埋め込みベクトルを追加します。
        *   出力: なし。
    *   `search(queries: Union[str, List[str]], threshold: float = 0.6, top_k: int = 5, ...)`:
        *   処理内容: 1つ以上のクエリ文を受け取り、構築済みのインデックス内で類似する文を検索します。`top_k` 個の最も類似した文を、類似度スコアが `threshold` 以上のものに限り返します。Faiss インデックスが利用可能な場合はそれを使用します。
        *   出力: 検索結果のリスト。各クエリに対して、(類似文, 類似度スコア) のタプルのリストが返されます。
*   **評価フレームワークでの利用**:
    `eval_r.py` で `SimCSE` クラスがインスタンス化され、`similarity()` メソッドがR-Simスコア計算のために直接利用されます。

## 4. `trainers.py`

*   **役割**:
    SimCSE モデルの訓練を行うためのカスタム Hugging Face `Trainer` である `CLTrainer` を定義しています。SentEval ベンチマークスイートを用いた評価ロジックや、最適なチェックポイントのみを保存するカスタム保存戦略などが含まれています。
*   **`CLTrainer(Trainer)` クラスの主要な機能**:
    *   `evaluate(eval_dataset, ..., eval_senteval_transfer: bool = False)`:
        *   処理内容: 標準的な評価データセットを用いた評価に加え、SentEval のタスク (STSBenchmark, SICKRelatedness や、オプションでMR, CR, SST2などの転移タスク) を用いた評価を実行します。モデルから文埋め込みを抽出し、SentEval の評価パイプラインに渡して、スピアマン相関係数 (STSタスク) や精度 (分類タスク) を計算します。
        *   出力: 評価メトリクスの辞書。
    *   `_save_checkpoint(model, trial, metrics=None)`:
        *   処理内容: Hugging Face Trainer のチェックポイント保存機能をオーバーライドし、指定されたメトリック (`metric_for_best_model`) に基づいて最高のパフォーマンスを示したチェックポイントのみを保存するように変更されています。
    *   `train(model_path: Optional[str] = None, ...)`:
        *   処理内容: モデルの訓練ループを実行します。オリジナルの `Trainer.train` メソッドとほぼ同様ですが、最良モデルをロードする際に `model_args` も考慮するなどの微調整が含まれている可能性があります。
*   **評価フレームワークでの利用**:
    HyperGraphRAG の評価自体では、この `CLTrainer` を用いた SimCSE モデルの再訓練は行われません。`eval_r.py` は事前学習済みの SimCSE モデルを利用します。このファイルは、SimCSE モデルを独自に訓練またはファインチューニングする場合に役立つコンポーネントです。

## サブモジュール間の関連性

`evaluation/simcse` サブモジュールは、主に `tool.py` の `SimCSE` クラスを通じて、`evaluation/eval_r.py` から利用されます。`eval_r.py` は `SimCSE` インスタンスを作成し、その `similarity` メソッドを使って、検索された知識と正解コンテキスト間の意味的類似度を計算します。`models.py` と `trainers.py` は SimCSE モデルの定義と訓練に関連するファイルですが、評価スクリプト実行時には直接使用されず、`tool.py` が依存する事前学習済みモデルの背景となる技術を提供しています。
