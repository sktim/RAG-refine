# HyperGraphRAG コアモジュール (`hypergraphrag`) ドキュメント

このドキュメントは、HyperGraphRAG プロジェクトのコア機能を提供する `hypergraphrag` モジュール内の各ファイルの役割、主要な関数、およびそれらの処理内容について説明します。

## 1. `hypergraphrag.py`

*   **役割**:
    このファイルは、`HyperGraphRAG` という主要なクラスを定義しています。このクラスは、知識ハイパーグラフの構築、管理、およびクエリ処理全体のオーケストレーションを担当します。設定の初期化、各種ストレージバックエンドの管理、データ挿入 (`insert`) とクエリ (`query`) の主要なエントリーポイントを提供します。

*   **主要な関数と処理内容**:
    *   `HyperGraphRAG(__init__)`:
        *   処理内容: RAG システムの各種設定 (作業ディレクトリ、チャンクサイズ、LLMモデル、ストレージタイプなど) を初期化します。設定に基づいて、キーバリューストア、ベクトルデータベース、グラフストレージのインスタンスを生成します。LLM の応答キャッシュやエンベディングキャッシュもここで設定されます。
        *   出力: 初期化され、利用可能な状態になった `HyperGraphRAG` インスタンス。
    *   `HyperGraphRAG.insert(string_or_strings)` (同期) / `HyperGraphRAG.ainsert(string_or_strings)` (非同期):
        *   処理内容:
            1.  入力された文字列 (単一または複数) を受け取ります。
            2.  各文字列をドキュメントとして扱い、MD5 ハッシュから ID を生成します。
            3.  ドキュメントが既に存在しない場合、`operate.chunking_by_token_size` を使用してドキュメントをテキストチャンクに分割します。
            4.  新しいチャンクに対して `operate.extract_entities` を呼び出し、エンティティとハイパーリレーション (知識の断片) を抽出します。これには、`prompt.PROMPTS["entity_extraction"]` を利用した LLM の呼び出しが含まれます。
            5.  抽出されたエンティティとハイパーリレーションは、設定されたグラフストレージ (例: `NetworkXStorage`) にノードやエッジとして格納され、関連する情報はベクトルデータベース (例: `NanoVectorDBStorage` の `entities_vdb`、`hyperedges_vdb`) にも格納されます。
            6.  元のドキュメントとチャンクは、キーバリューストア (例: `JsonKVStorage` の `full_docs`、`text_chunks`) に保存されます。
        *   出力: 各データベース (KVストア、ベクトルDB、グラフDB) が更新された状態。具体的に返り値はありませんが、インスタンス内部のストレージが更新されます。
    *   `HyperGraphRAG.insert_custom_kg(custom_kg: dict)` (同期) / `HyperGraphRAG.ainsert_custom_kg(custom_kg: dict)` (非同期):
        *   処理内容: 事前に定義されたカスタムナレッジグラフ (チャンク、エンティティ、リレーションシップを含む辞書) を受け入れます。これらの要素を適切なストレージ (チャンクVDB、エンティティVDB、ハイパーエッジVDB、グラフストレージ) に直接挿入します。エンティティとリレーションシップのコンテンツからベクトル埋め込みを生成し、VDBに保存します。
        *   出力: 各データベースが更新された状態。
    *   `HyperGraphRAG.query(query: str, param: QueryParam = QueryParam())` (同期) / `HyperGraphRAG.aquery(query: str, param: QueryParam = QueryParam())` (非同期):
        *   処理内容:
            1.  ユーザーからの質問文字列と `QueryParam` (検索モード、トップK、応答タイプなどを指定) を受け取ります。
            2.  `QueryParam.mode` (`hybrid`, `local`, `global`, `naive`) に応じて、`operate.kg_query` (または他のクエリ関数、現在は主に `kg_query`) を呼び出します。
            3.  `kg_query` は、まずクエリからキーワードを抽出します (LLM を使用)。
            4.  抽出されたキーワードと検索モードに基づき、関連するエンティティ、リレーションシップ、テキストチャンクをグラフDBとベクトルDBから検索します (詳細なロジックは `operate.py` 内の `_get_node_data` や `_get_edge_data` で処理されます)。
            5.  取得された情報を整形し、`prompt.PROMPTS["rag_response"]` テンプレートを使用して LLM への最終的なプロンプトを構築します。
            6.  LLM を呼び出し、回答を生成します。
            7.  LLM の応答キャッシュが有効な場合、結果をキャッシュに保存します。
        *   出力: LLM によって生成された回答文字列、または `QueryParam.only_need_context` が True の場合は検索されたコンテキスト文字列。
    *   `HyperGraphRAG.delete_by_entity(entity_name: str)` (同期) / `HyperGraphRAG.adelete_by_entity(entity_name: str)` (非同期):
        *   処理内容: 指定されたエンティティ名に基づいて、エンティティVDB、ハイパーエッジVDB、およびチャンクエンティティ関連グラフからエンティティとその関連情報を削除します。
        *   出力: データベースが更新された状態。

## 2. `base.py`

*   **役割**:
    このファイルは、プロジェクト全体で使用される基本的なデータクラス (dataclass) と型定義 (TypedDict、TypeVar) を提供します。これには、クエリパラメータ、ストレージの名前空間、各種ストレージ (ベクトル、キーバリュー、グラフ) の抽象ベースクラスが含まれており、具体的なストレージ実装のインターフェースを定義します。
*   **主要な定義**:
    *   `TextChunkSchema`: テキストチャンクの構造を定義する型辞書 (トークン数、内容、ドキュメントIDなど)。
    *   `QueryParam`: クエリ実行時のパラメータ (モード、トップK、最大トークン数など) を保持するデータクラス。
    *   `StorageNameSpace`: ストレージの基本設定 (名前空間、グローバル設定) を保持するデータクラス。`index_done_callback` や `query_done_callback` といったコールバックメソッドの雛形も持ちます。
    *   `BaseVectorStorage(StorageNameSpace)`: ベクトルストレージの抽象ベースクラス。`query` (ベクトル検索) と `upsert` (ベクトル挿入/更新) のインターフェースを定義します。
    *   `BaseKVStorage(StorageNameSpace)`: キーバリューストレージの抽象ベースクラス。`all_keys`, `get_by_id`, `get_by_ids`, `filter_keys`, `upsert`, `drop` のインターフェースを定義します。
    *   `BaseGraphStorage(StorageNameSpace)`: グラフストレージの抽象ベースクラス。ノードやエッジの存在確認、取得、次数計算、挿入/更新、削除などのインターフェースを定義します。

## 3. `llm.py`

*   **役割**:
    このファイルは、様々な大規模言語モデル (LLM) および埋め込みモデルとのインタラクションを管理します。OpenAI、Azure OpenAI、Bedrock、HuggingFace トランスフォーマーモデル、Ollama、LMDeploy、ZhipuAI など、複数のプロバイダーやモデルタイプに対応するための関数を提供します。API呼び出しの際のリトライ処理、キャッシュ機構 (HyperGraphRAGクラスの `llm_response_cache` を利用)、非同期処理の並列数制限なども扱います。
*   **主要な関数と処理内容**:
    *   `openai_complete_if_cache` (および各種モデルプロバイダーに対応する `*_complete_if_cache` 関数群):
        *   処理内容: 指定されたモデル、プロンプト、システムプロンプト、履歴メッセージなどを用いて、LLM に補完 (テキスト生成) を要求します。APIキーやベースURLなどの設定も扱います。キャッシュが存在し、条件に合致する場合はキャッシュされた応答を返します。ストリーミング応答もサポートする場合があります。
        *   出力: LLM によって生成されたテキスト文字列、またはストリーミングの場合は非同期イテレータ。
    *   `openai_embedding` (および各種モデルプロバイダーに対応する `*_embedding` 関数群):
        *   処理内容: 入力されたテキストリストに対して、指定された埋め込みモデルを使用し、テキストのベクトル埋め込みを生成します。
        *   出力: テキスト埋め込みの NumPy 配列。
    *   `gpt_4o_mini_complete`, `openai_complete`, `azure_openai_complete`, `bedrock_complete`, `hf_model_complete`, `ollama_model_complete`, `zhipu_complete` など:
        *   処理内容: `HyperGraphRAG` の設定 (`llm_model_name` など) に基づいて、具体的な `*_complete_if_cache` 関数を呼び出すラッパー関数。キーワード抽出モードの場合、JSON形式の応答を期待するよう設定を調整することがあります。
        *   出力: LLM によって生成されたテキスト文字列または `GPTKeywordExtractionFormat` のような構造化データ。
    *   `EmbeddingFunc` (utils.py で定義されているが、ここで利用される):
        *   処理内容: 埋め込み関数のラッパーで、埋め込み次元数、最大トークンサイズ、同時実行制限などの属性を持ちます。
    *   `MultiModel`:
        *   処理内容: 複数のLLMモデル/APIキーをラウンドロビン方式で使用するためのクラス。レート制限の回避などに利用できます。
        *   出力: `llm_model_func` として `HyperGraphRAG` に提供できる関数。

## 4. `operate.py`

*   **役割**:
    このファイルは、HyperGraphRAG システムの主要な操作ロジックを実装しています。テキストのチャンク化、LLM を用いたエンティティおよびハイパーリレーション (知識の断片) の抽出、そして RAG プロセスにおけるコンテキスト検索と構築のコア処理を担当します。
*   **主要な関数と処理内容**:
    *   `chunking_by_token_size(content: str, ...)`:
        *   処理内容: 入力されたテキストコンテンツを、指定された最大トークンサイズとオーバーラップトークンサイズに基づいてチャンクに分割します。`tiktoken` を使用してトークン数を計算します。
        *   出力: チャンク情報のリスト。各チャンクはトークン数、内容、ドキュメント内での順序インデックスを含みます (`TextChunkSchema` に類似)。
    *   `extract_entities(chunks: dict, knowledge_graph_inst: BaseGraphStorage, entity_vdb: BaseVectorStorage, hyperedge_vdb: BaseVectorStorage, global_config: dict)`:
        *   処理内容:
            1.  テキストチャンクの辞書を受け取ります。
            2.  各チャンクの内容について、`prompt.PROMPTS["entity_extraction"]` プロンプトテンプレートと設定されたLLM (`global_config["llm_model_func"]`) を使用して、エンティティとハイパーリレーションを抽出します。プロンプトには、抽出対象のエンティティタイプや言語、抽出例などが含まれます。
            3.  抽出されたエンティティとハイパーリレーションの情報を集約します。エンティティについては、名前、タイプ、説明、重要度スコアなどを、ハイパーリレーションについては、知識の断片、完全性スコアなどを抽出します。
            4.  同じエンティティ名やハイパーリレーション名を持つ情報が集約され、説明は `_handle_entity_relation_summary` で要約されることがあります。
            5.  集約・処理されたエンティティは、`_merge_nodes_then_upsert` を通じてグラフストレージにノードとして、またその内容はエンティティベクトルDB (`entity_vdb`) に格納されます。
            6.  集約・処理されたハイパーリレーションは、`_merge_hyperedges_then_upsert` を通じてグラフストレージにノード (ハイパーエッジを表すノード) として、またその内容はハイパーエッジベクトルDB (`hyperedge_vdb`) に格納されます。
            7.  エンティティとそれが属するハイパーリレーションとの間の関連は、`_merge_edges_then_upsert` を通じてグラフストレージにエッジとして格納されます。
        *   出力: 更新された `knowledge_graph_inst` (グラフストレージインスタンス)。エンティティやハイパーリレーションが抽出されなかった場合は `None`。
    *   `kg_query(query: str, knowledge_graph_inst: BaseGraphStorage, entities_vdb: BaseVectorStorage, hyperedges_vdb: BaseVectorStorage, text_chunks_db: BaseKVStorage, query_param: QueryParam, global_config: dict, hashing_kv: BaseKVStorage = None)`:
        *   処理内容: RAG のクエリ処理を行います。
            1.  まず、ユーザーの `query` からキーワード (高レベルおよび低レベル) を抽出します。これには `prompt.PROMPTS["entity_extraction"]` (キーワード抽出に転用) または類似のプロンプトとLLMが使用されます。
            2.  `query_param.mode` ("local", "global", "hybrid") と抽出されたキーワードに基づき、`_build_query_context` を呼び出します。
            3.  `_build_query_context` は、モードに応じて `_get_node_data` (ローカル検索: エンティティVDBとグラフからエンティティ、関連チャンク、関連リレーションを取得) や `_get_edge_data` (グローバル検索: ハイパーエッジVDBとグラフからハイパーエッジ、関連エンティティ、関連チャンクを取得) を呼び出します。
            4.  これらの関数は、ベクトル検索、グラフ探索、キーバリューストアからのデータ取得を組み合わせて、関連性の高いコンテキスト情報を収集・整形します (CSV形式の文字列として)。
            5.  収集されたコンテキストは `prompt.PROMPTS["rag_response"]` テンプレートに挿入され、元のクエリと共にLLMに渡されて最終的な回答が生成されます。
            6.  `query_param.only_need_context` が True の場合、生成されたコンテキスト文字列を返します。
            7.  `query_param.only_need_prompt` が True の場合、LLMへの最終プロンプトを返します。
            8.  結果は `hashing_kv` (LLM応答キャッシュ) に保存されます。
        *   出力: LLMによって生成された回答文字列、または指定によりコンテキスト文字列かプロンプト文字列。
    *   `_get_node_data`, `_get_edge_data`, `_find_most_related_text_unit_from_entities`, `_find_most_related_edges_from_entities`, `_find_most_related_entities_from_relationships`, `_find_related_text_unit_from_relationships`, `combine_contexts`:
        *   処理内容: `kg_query` のヘルパー関数群。それぞれが特定の検索モードやデータタイプ (エンティティ、リレーション、テキストユニット) に基づいて、データベースから情報を取得し、フィルタリング、ランキング、トークン数による切り捨てなどを行い、最終的なコンテキスト部分文字列を構築します。
        *   出力: 整形されたコンテキスト情報 (通常はCSV形式の文字列)。

## 5. `prompt.py`

*   **役割**:
    このファイルは、システムがLLMと対話する際に使用するすべてのプロンプトテンプレートを集中管理します。プロンプトは辞書 `PROMPTS` に格納されており、キーによって識別されます。これにより、プロンプトの変更や管理が容易になります。
*   **主要なプロンプト**:
    *   `PROMPTS["entity_extraction"]`: テキストからエンティティとハイパーリレーションを抽出するための詳細な指示と例を含むプロンプト。抽出フォーマット (タプル区切り文字、レコード区切り文字など) も定義されています。
    *   `PROMPTS["summarize_entity_descriptions"]`: 複数の情報源から得られたエンティティの説明を統合し、要約するためのプロンプト。
    *   `PROMPTS["entity_continue_extraction"]`, `PROMPTS["entity_if_loop_extraction"]`: エンティティ抽出処理で、より多くの情報を抽出するための追加指示や、処理を継続するかどうかをLLMに判断させるためのプロンプト。
    *   `PROMPTS["rag_response"]`: RAGプロセスで最終的な回答を生成する際に、検索されたコンテキストとユーザーの質問をLLMに提供するためのメインプロンプト。応答の形式 (例: "Multiple Paragraphs") も指定できます。
    *   `PROMPTS["keywords_extraction"]`: ユーザーのクエリから高レベルおよび低レベルのキーワードを抽出するためのプロンプト。JSON形式での出力を期待します。(注: `operate.kg_query` の実装では `entity_extraction` プロンプトをキーワード抽出に利用しているように見えますが、このプロンプトも定義されています。)
    *   `PROMPTS["naive_rag_response"]`: (評価用などで)単純な検索拡張生成を行う場合のプロンプト。
    *   `PROMPTS["similarity_check"]`: (キャッシュ機能で) 2つの質問の類似性をLLMに評価させるためのプロンプト。
*   **その他**:
    *   `GRAPH_FIELD_SEP`: グラフ関連データ内で複数の値を区切るためのセパレータ (例: `<SEP>`)。
    *   `DEFAULT_LANGUAGE`, `DEFAULT_TUPLE_DELIMITER`, `DEFAULT_RECORD_DELIMITER`, `DEFAULT_COMPLETION_DELIMITER`: プロンプト内で使用されるデフォルトの言語や区切り文字。
    *   `DEFAULT_ENTITY_TYPES`: エンティティ抽出のデフォルト対象タイプ。

## 6. `storage.py`

*   **役割**:
    このファイルは、`base.py` で定義された抽象ストレージインターフェースの具体的な実装を提供します。デフォルトでは、JSONファイルベースのキーバリューストア、`nano_vectordb` ライブラリを使用したベクトルデータベース、`networkx` ライブラリを使用したグラフデータベースが実装されています。これらは `HyperGraphRAG` クラスで、ユーザーがより高度な外部データベース (例: Neo4j, Milvus) を指定しない場合のフォールバックとして使用されます。
*   **主要なクラスと処理内容**:
    *   `JsonKVStorage(BaseKVStorage)`:
        *   処理内容: キーバリューデータをメモリ上の辞書として保持し、指定されたJSONファイルに永続化します。作業ディレクトリ内に名前空間ごとのJSONファイル (`kv_store_{namespace}.json`) を作成・利用します。
        *   `__post_init__`: ファイルからデータをロード。
        *   `upsert`: 新しいデータを辞書に追加。
        *   `get_by_id`, `get_by_ids`, `all_keys`, `filter_keys`: 標準的なKV操作。
        *   `index_done_callback`: メモリ上のデータをJSONファイルに書き込みます。
    *   `NanoVectorDBStorage(BaseVectorStorage)`:
        *   処理内容: `nano_vectordb` ライブラリを利用してベクトルデータを管理します。ベクトルデータとメタデータはJSONファイル (`vdb_{namespace}.json`) に保存されます。
        *   `__post_init__`: `NanoVectorDB` インスタンスを初期化し、ファイルからデータをロード。
        *   `upsert`: 入力データからコンテンツの埋め込みベクトルを生成 (`embedding_func` を使用) し、`nano_vectordb` にID、メタデータと共に挿入します。
        *   `query`: クエリ文字列の埋め込みベクトルを生成し、`nano_vectordb` でコサイン類似度検索を実行します。`cosine_better_than_threshold` で結果をフィルタリングします。
        *   `delete_entity`, `delete_relation`: (この実装では)エンティティ名やリレーション名に基づいてIDを計算し、関連するベクトルを削除しようと試みます (ただし、NanoVectorDB自体がリレーションの概念を持つわけではないため、メタデータやIDの命名規則に依存する可能性があります)。
        *   `index_done_callback`: `nano_vectordb` の `save()` メソッドを呼び出し、データをファイルに永続化します。
    *   `NetworkXStorage(BaseGraphStorage)`:
        *   処理内容: `networkx` ライブラリを使用してグラフデータをメモリ上に保持し、GraphML形式のファイル (`graph_{namespace}.graphml`) に永続化します。
        *   `__post_init__`: GraphMLファイルからグラフをロード。
        *   `upsert_node`, `upsert_edge`: `networkx` の機能を使ってノードやエッジを追加・更新。
        *   `has_node`, `has_edge`, `get_node`, `get_edge`, `node_degree`, `edge_degree`, `get_node_edges`, `delete_node`: 標準的なグラフ操作を `networkx` のAPIを通じて提供。
        *   `index_done_callback`: メモリ上のグラフをGraphMLファイルに書き込みます。
        *   `embed_nodes`: (現在は `node2vec` のみ) グラフ構造に基づいてノード埋め込みを生成する機能 (ただし、HyperGraphRAGの主要フローでは直接使用されていない可能性あり)。

## 7. `utils.py`

*   **役割**:
    このファイルは、プロジェクト全体で共通して使用される様々なユーティリティ関数やクラスを提供します。ロギング設定、非同期処理の制御、データ構造の変換、ハッシュ計算、トークン化処理、文字列操作、キャッシュ関連処理などが含まれます。
*   **主要な関数・クラスと処理内容**:
    *   `set_logger(log_file: str)`: プロジェクト用のロガー (`hypergraphrag`) を設定します。ファイルへのログ出力やフォーマットを指定します。
    *   `EmbeddingFunc`: 埋め込み関数のラッパークラス。埋め込み次元、最大トークンサイズ、同時実行セマフォなどを保持します。
    *   `wrap_embedding_func_with_attrs(**kwargs)`: 関数を `EmbeddingFunc` インスタンスでラップするためのデコレータ。
    *   `locate_json_string_body_from_string(content: str)`: 文字列中からJSON形式の部分文字列を抽出します。
    *   `convert_response_to_json(response: str)`: LLMの応答文字列をJSONオブジェクトに変換します (上記関数を利用)。
    *   `compute_args_hash(*args)`: 与えられた引数からMD5ハッシュ値を計算します (キャッシュキーなどに利用)。
    *   `compute_mdhash_id(content, prefix: str = "")`: コンテンツ文字列からMD5ハッシュIDを生成します。
    *   `limit_async_func_call(max_size: int, ...)`: 非同期関数の同時実行数を制限するためのデコレータ。
    *   `load_json(file_name)`, `write_json(json_obj, file_name)`: JSONファイルの読み書き。
    *   `encode_string_by_tiktoken(content: str, model_name: str)`, `decode_tokens_by_tiktoken(tokens: list[int], model_name: str)`: `tiktoken` ライブラリを使用して、指定されたモデルに基づき文字列とトークンリスト間のエンコード・デコードを行います。
    *   `pack_user_ass_to_openai_messages(*args: str)`: ユーザーとアシスタントの発言をOpenAIのメッセージフォーマットに整形します。
    *   `split_string_by_multi_markers(content: str, markers: list[str])`: 複数の区切り文字で文字列を分割します。
    *   `clean_str(input: Any)`: HTMLエスケープ解除や制御文字除去など、文字列をクリーニングします。
    *   `is_float_regex(value)`: 文字列が浮動小数点数を表すか正規表現でチェックします。
    *   `truncate_list_by_token_size(list_data: list, key: callable, max_token_size: int)`: リスト内の各要素について `key` 関数で文字列を取得し、合計トークン数が `max_token_size` を超えないようにリストを切り詰めます。
    *   `list_of_list_to_csv(data: List[List[str]])`, `csv_string_to_list(csv_string: str)`: リストのリストとCSV文字列間の変換。
    *   `CacheData`: キャッシュするデータを保持するデータクラス。
    *   `handle_cache(...)`, `save_to_cache(...)`, `get_best_cached_response(...)`: LLM応答や埋め込みのキャッシュ処理に関連する関数群。埋め込みキャッシュでは、コサイン類似度やLLMによる類似度チェック、埋め込みの量子化・逆量子化も扱います。
    *   `safe_unicode_decode(content)`: Unicodeエスケープシーケンスを実際の文字にデコードします。

## モジュール間の関連性

`hypergraphrag` モジュール内のファイルは密接に連携して動作します。

1.  **`hypergraphrag.py` (エントリーポイント)**:
    *   ユーザーからのデータ挿入 (`insert`) やクエリ (`query`) のリクエストを受け付けます。
    *   設定に基づき、`storage.py` (または `kg` 以下の具体的な実装) のストレージクラスをインスタンス化して利用します。
    *   データ処理のコアロジックは `operate.py` の関数群 (例: `extract_entities`, `kg_query`) に委譲します。

2.  **`operate.py` (コアロジック)**:
    *   `hypergraphrag.py` から呼び出され、チャンキング、エンティティ抽出、コンテキスト検索などの主要な処理を実行します。
    *   エンティティ抽出やキーワード抽出、最終的な回答生成のために、`llm.py` を介してLLMとのインタラクションを行います。この際、`prompt.py` に定義されたプロンプトテンプレートを使用します。
    *   抽出されたデータや検索結果の永続化・取得のために、`storage.py` (または `kg` 以下の実装) のストレージインスタンス (グラフDB、ベクトルDB、KVストア) を操作します。

3.  **`llm.py` (LLM層)**:
    *   `operate.py` から呼び出され、具体的なLLM API (OpenAI, Azureなど) との通信を抽象化します。
    *   埋め込み生成やテキスト補完の機能を提供します。
    *   `utils.py` のキャッシュ機構を利用してLLMの応答をキャッシュすることがあります。

4.  **`prompt.py` (プロンプト管理)**:
    *   `operate.py` や `llm.py` (キャッシュの類似度チェックなど) でLLMを呼び出す際に、状況に応じたプロンプトを提供します。

5.  **`storage.py` (デフォルトストレージ実装) / `kg/*.py` (外部DBストレージ実装)**:
    *   `base.py` で定義されたストレージインターフェースを実装します。
    *   `hypergraphrag.py` でインスタンス化され、`operate.py` を通じてデータの読み書きが行われます。

6.  **`base.py` (基本定義)**:
    *   モジュール全体で共通して使用されるデータ構造 (例: `QueryParam`) や、ストレージ実装が準拠すべきインターフェースを定義することで、モジュール全体の整合性と拡張性を高めます。

7.  **`utils.py` (ユーティリティ)**:
    *   モジュール内の様々なファイルから、共通的に必要とされる補助機能 (ロギング、トークン化、ハッシング、キャッシュなど) を提供します。

このように、各ファイルが特定の責務を持ちつつ、互いに連携することで HyperGraphRAG システム全体の機能を実現しています。
