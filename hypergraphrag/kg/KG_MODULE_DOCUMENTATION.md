# `hypergraphrag/kg` サブモジュール ドキュメント

このドキュメントは、`hypergraphrag` プロジェクト内の `kg` (Knowledge Graph) サブモジュールの役割と、その中に含まれる各データベース実装ファイルについて説明します。

`kg` サブモジュールは、`HyperGraphRAG` システムが使用するキーバリューストア、ベクトルデータベース、グラフデータベースといった各種ストレージについて、様々な外部データベース製品への接続と操作を可能にするための具体的な実装を提供します。`hypergraphrag/storage.py` にあるデフォルト実装 (JSONベースのKVストア、NanoVectorDB、NetworkX) の代替として、よりスケーラブルで高性能なデータベース製品を利用したい場合に、これらの実装が選択されます。

各実装ファイルは、通常 `hypergraphrag/base.py` で定義された `BaseKVStorage`、`BaseVectorStorage`、または `BaseGraphStorage` のいずれかの抽象ベースクラスを継承し、そのインターフェースに従って特定のデータベース製品向けの処理を記述します。

## 1. `__init__.py`

*   **役割**:
    Python のパッケージとして `kg` ディレクトリを認識させるための標準的なファイルです。現在の実装では、このファイル自体に特別なコードは含まれていません。

## 2. `chroma_impl.py`

*   **ファイル役割**:
    ベクトルデータベースとして ChromaDB を利用するための実装 `ChromaVectorDBStorage(BaseVectorStorage)` を提供します。
*   **主要な機能と処理内容**:
    *   コンストラクタ (`__post_init__`):
        *   処理内容: ChromaDB クライアント (`HttpClient`) を初期化し、設定されたホスト、ポート、認証情報を用いて ChromaDB サーバーに接続します。指定された名前空間 (コレクション名) でコレクションを取得または作成します。コレクション作成時には、HNSW インデックスの設定 (距離メトリック、ef 値など) や埋め込み次元数を指定できます。
        *   出力: 初期化された `ChromaVectorDBStorage` インスタンス。
    *   `upsert(data: dict[str, dict])`:
        *   処理内容: 入力データ (キーがID、値が内容とメタデータを含む辞書) を受け取ります。各データの内容 (`content`) から `embedding_func` を用いて埋め込みベクトルを生成し、ID、ドキュメント (内容)、メタデータと共に ChromaDB のコレクションにバッチで挿入 (upsert) します。
        *   出力: 挿入されたアイテムのIDリスト (ChromaDBの応答による)。
    *   `query(query: str, top_k=5)`:
        *   処理内容: クエリ文字列を受け取り、`embedding_func` で埋め込みベクトルを生成します。生成されたベクトルを使用して ChromaDB のコレクションを検索し、類似度の高い上位 `top_k` 個の結果を取得します。結果にはID、距離 (1 - コサイン類似度)、内容、メタデータが含まれます。`cosine_better_than_threshold` で足切りの閾値を設けることも可能です。
        *   出力: 検索結果のリスト。各要素はID、距離、内容、メタデータを含む辞書。
    *   `index_done_callback()`:
        *   処理内容: ChromaDB は通常、操作を自動的に永続化するため、このコールバックでは特別な処理は行いません。

## 3. `milvus_impl.py`

*   **ファイル役割**:
    ベクトルデータベースとして Milvus を利用するための実装 `MilvusVectorDBStorge(BaseVectorStorage)` を提供します。
*   **主要な機能と処理内容**:
    *   コンストラクタ (`__post_init__`):
        *   処理内容: Milvus クライアント (`MilvusClient`) を初期化し、設定されたURI、ユーザー、パスワードなどを用いて Milvus サーバーに接続します。指定された名前空間 (コレクション名) でコレクションが存在しない場合は作成します。コレクション作成時には、埋め込み次元数やIDの型などを指定します。
        *   出力: 初期化された `MilvusVectorDBStorge` インスタンス。
    *   `upsert(data: dict[str, dict])`:
        *   処理内容: 入力データから埋め込みベクトルを生成し、ID、ベクトル、およびメタフィールド (`self.meta_fields` で指定されたキー) の値を Milvus のコレクションに挿入 (upsert) します。
        *   出力: Milvus の `upsert` 操作の結果 (通常は挿入/更新されたIDの情報)。
    *   `query(query, top_k=5)`:
        *   処理内容: クエリ文字列の埋め込みベクトルを生成し、Milvus コレクションを検索します。コサイン類似度 (`COSINE`) を用いて類似ベクトルを検索し、上位 `top_k` 件の結果を取得します。結果にはID、距離、および指定された出力フィールドが含まれます。
        *   出力: 検索結果のリスト。各要素はID、距離、およびエンティティ情報を含む辞書。

## 4. `mongo_impl.py`

*   **ファイル役割**:
    キーバリューストアとして MongoDB を利用するための実装 `MongoKVStorage(BaseKVStorage)` を提供します。
*   **主要な機能と処理内容**:
    *   コンストラクタ (`__post_init__`):
        *   処理内容: MongoDB クライアント (`MongoClient`) を初期化し、環境変数などから取得した接続URI、データベース名を用いて MongoDB サーバーに接続します。指定された名前空間 (コレクション名) のコレクションオブジェクトを取得します。
        *   出力: 初期化された `MongoKVStorage` インスタンス。
    *   `upsert(data: dict[str, dict])`:
        *   処理内容: 入力されたキーバリューのペアを MongoDB のコレクションに挿入または更新します。MongoDB の `update_one` メソッドと `{ "$set": value }` および `upsert=True` オプションを使用します。キーは `_id` フィールドとして扱われます。
        *   出力: 処理されたデータ (入力データに `_id` を付与したもの)。
    *   `get_by_id(id)`, `get_by_ids(ids, fields=None)`, `all_keys()`, `filter_keys(data: list[str])`:
        *   処理内容: MongoDB の `find_one` や `find` メソッドを使用して、標準的なキーバリュー取得操作、全キーリスト取得、存在しないキーのフィルタリング機能を提供します。
        *   出力: それぞれの操作に応じたデータ (単一ドキュメント、ドキュメントリスト、キーリスト、存在しないキーのセット)。

## 5. `neo4j_impl.py`

*   **ファイル役割**:
    グラフデータベースとして Neo4j を利用するための実装 `Neo4JStorage(BaseGraphStorage)` を提供します。
*   **主要な機能と処理内容**:
    *   コンストラクタ (`__init__`, `__post_init__`):
        *   処理内容: Neo4j Python ドライバ (`AsyncGraphDatabase.driver`) を使用して、環境変数から取得したURI、ユーザー名、パスワードで Neo4j サーバーへの非同期接続を確立します。
        *   出力: 初期化された `Neo4JStorage` インスタンス。
    *   `upsert_node(node_id: str, node_data: Dict[str, Any])`:
        *   処理内容: Cypher クエリの `MERGE` 句を使用して、指定された `node_id` (通常はエンティティ名をラベルとして使用) のノードを作成または更新します。`node_data` の内容をノードのプロパティとして設定します。
        *   出力: なし (データベースが更新される)。
    *   `upsert_edge(source_node_id: str, target_node_id: str, edge_data: Dict[str, Any])`:
        *   処理内容: Cypher クエリの `MATCH` と `MERGE` 句を使用して、ソースノードとターゲットノード間に `DIRECTED` というタイプのリレーションシップを作成または更新します。`edge_data` の内容をリレーションシップのプロパティとして設定します。
        *   出力: なし (データベースが更新される)。
    *   `has_node(node_id: str)`, `has_edge(source_node_id: str, target_node_id: str)`, `get_node(node_id: str)`, `get_edge(source_node_id: str, target_node_id: str)`, `node_degree(node_id: str)`, `get_node_edges(source_node_id: str)`:
        *   処理内容: それぞれ Cypher クエリを実行して、ノード/エッジの存在確認、プロパティ取得、次数計算、特定ノードに接続するエッジの取得など、標準的なグラフ操作を行います。
        *   出力: それぞれの操作に応じたデータ (ブール値、辞書、数値、タプルのリストなど)。
    *   `index_done_callback()`:
        *   処理内容: Neo4j は通常、トランザクションごとにデータを永続化するため、ここでは特別な処理は行いません。
    *   リトライ処理: Neo4j との通信で発生しうる一時的なエラー (例: `ServiceUnavailable`) に対して、指数関数的バックオフを用いたリトライ処理が一部のメソッドに実装されています。

## 6. `oracle_impl.py`

*   **ファイル役割**:
    Oracle Database をキーバリューストア、ベクトルデータベース、グラフデータベースとして利用するための包括的な実装を提供します。`OracleDB` クラスがデータベース接続と共通操作を管理し、`OracleKVStorage`、`OracleVectorDBStorage`、`OracleGraphStorage` がそれぞれのストレージタイプに対応します。
*   **主要な機能と処理内容 (`OracleDB` クラス)**:
    *   コンストラクタ: Oracle Database への非同期接続プール (`oracledb.create_pool_async`) を作成します。接続情報 (ユーザー、パスワード、DSNなど) は設定から取得します。NumPy 配列と Oracle の VECTOR 型を相互変換するための入出力タイプハンドラも設定します。
    *   `check_tables()`: `TABLES` ディクショナリに定義されたDDLに基づき、必要なテーブル (例: `HYPERGRAPHRAG_DOC_FULL`, `HYPERGRAPHRAG_GRAPH_NODES`, `HYPERGRAPHRAG_GRAPH_EDGES`) やプロパティグラフ (`hypergraphrag_graph`) が存在しない場合に作成します。
    *   `query()`, `execute()`: SQLクエリの実行と結果取得、およびDML/DDLの実行を非同期で行います。
*   **`OracleKVStorage(BaseKVStorage)`**:
    *   `upsert()`: `full_docs` の場合はドキュメント内容を、`text_chunks` の場合はチャンク内容とその埋め込みベクトルを、対応するテーブル (`HYPERGRAPHRAG_DOC_FULL`, `HYPERGRAPHRAG_DOC_CHUNKS`) にマージ (MERGE) します。
    *   `get_by_id()`, `get_by_ids()`, `filter_keys()`: SQLクエリを用いてKVデータを取得・フィルタリングします。
*   **`OracleVectorDBStorage(BaseVectorStorage)`**:
    *   `query()`: クエリ文字列の埋め込みベクトルを生成し、指定された名前空間 (entities, relationships, chunks) に応じて、対応するテーブル (`HYPERGRAPHRAG_GRAPH_NODES`, `HYPERGRAPHRAG_GRAPH_EDGES`, `HYPERGRAPHRAG_DOC_CHUNKS`) のベクトル列に対して `VECTOR_DISTANCE` 関数 (COSINE) を用いた類似度検索SQLを実行します。
*   **`OracleGraphStorage(BaseGraphStorage)`**:
    *   `upsert_node()`: ノードの名称、タイプ、説明、ソースチャンクIDなどの情報と共に、内容の埋め込みベクトルを生成し、`HYPERGRAPHRAG_GRAPH_NODES` テーブルにマージします。
    *   `upsert_edge()`: ソースノード名、ターゲットノード名、重み、キーワード、説明などの情報と共に、内容の埋め込みベクトルを生成し、`HYPERGRAPHRAG_GRAPH_EDGES` テーブルにマージします。
    *   `has_node()`, `get_node()`, `has_edge()`, `get_edge()`, `node_degree()`, `get_node_edges()`: Oracle のプロパティグラフクエリ (PGQLライクな `GRAPH_TABLE` 構文) や標準SQLを用いて、グラフ操作機能を提供します。
*   **`SQL_TEMPLATES`**: 各操作に対応するSQLクエリテンプレートが多数定義されています。

## 7. `tidb_impl.py`

*   **ファイル役割**:
    TiDB をキーバリューストアおよびベクトルデータベースとして利用するための実装を提供します。`TiDB` クラスがデータベース接続を管理し、`TiDBKVStorage` と `TiDBVectorDBStorage` がそれぞれのストレージタイプに対応します。
*   **主要な機能と処理内容 (`TiDB` クラス)**:
    *   コンストラクタ: SQLAlchemy を使用して TiDB への接続エンジン (`create_engine`) を作成します。接続文字列は設定から構築されます。
    *   `check_tables()`: `TABLES` ディクショナリに定義されたDDLに基づき、必要なテーブル (例: `HYPERGRAPHRAG_DOC_FULL`, `HYPERGRAPHRAG_GRAPH_NODES`) が存在しない場合に作成します。TiDB の VECTOR 型や AUTO_RANDOM 主キーなどが使用されます。
    *   `query()`, `execute()`: SQLAlchemy の `text()` を用いてSQLクエリの実行と結果取得、およびDML/DDLの実行を行います。
*   **`TiDBKVStorage(BaseKVStorage)`**:
    *   `upsert()`: `full_docs` の場合はドキュメント内容を、`text_chunks` の場合はチャンク内容とその埋め込みベクトル (リストの文字列表現として) を、対応するテーブルに `INSERT ... ON DUPLICATE KEY UPDATE` を用いて挿入/更新します。
    *   `get_by_id()`, `get_by_ids()`, `filter_keys()`: SQLクエリを用いてKVデータを取得・フィルタリングします。
*   **`TiDBVectorDBStorage(BaseVectorStorage)`**:
    *   `query()`: クエリ文字列の埋め込みベクトルを生成し、指定された名前空間 (entities, relationships, chunks) に応じて、対応するテーブルのベクトル列に対して `VEC_COSINE_DISTANCE` 関数を用いた類似度検索SQLを実行します。
    *   `upsert()`: `entities` や `relationships` の場合、データの内容から埋め込みベクトルを生成し、対応するテーブル (`HYPERGRAPHRAG_GRAPH_NODES`, `HYPERGRAPHRAG_GRAPH_EDGES`) に `INSERT ... ON DUPLICATE KEY UPDATE` を用いて挿入/更新します。(注: `chunks` のVDB upsertは事実上何もしないようになっていますが、これはKVストレージ側で埋め込みと共に保存されるためかもしれません。)
*   **`SQL_TEMPLATES`**: 各操作に対応するSQLクエリテンプレートが定義されています。

これらの実装により、HyperGraphRAG は様々なデータベース環境での実行柔軟性を獲得しています。
