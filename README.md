# distributed-wiki

Claude Code 向けの LLM Wiki スキル実装。プロジェクト単位の Wiki を操作する `/wiki` と、どこからでも呼べるグローバルな Wiki を操作する `/gwiki` の2つのスキルを、**レジストリ型ネットワーク**という仕組みで緩く繋ぐ。

背景や設計思想の経緯については、こちらの記事にまとめている: [セカンドブレインは1つにまとめるな。分散Wiki構成が最強だった話](https://qiita.com/norisuke3@github/items/8ec42abae7ad6befbb0a)

## これは何か

[Andrej Karpathy 氏が提唱した LLM Wiki パターン](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)（`raw/` → `wiki/` → `schema` の3層構成で LLM に知識ベースを継続的にメンテさせる手法）を、Claude Code のスラッシュコマンド（スキル）として実装したもの。

単一のグローバルな Wiki に何でも放り込んでいくと、いずれ公私が一緒くたになってプライバシー管理が破綻する。この実装は、Wiki を最初から複数作る前提にして、それぞれを対等な存在として中央のレジストリ経由で緩く繋ぐことで、この問題を解決している。

## ディレクトリ構成

```
distributed-wiki/
  wiki/SKILL.md                  # プロジェクト単位の Wiki を操作するスキル
  gwiki/SKILL.md                 # どこからでも呼べるグローバル Wiki を操作するスキル
  wiki-sync-description.sh       # レジストリと各 Wiki の要約を同期するスクリプト
```
