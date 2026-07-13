---
name: gwiki
description: Global personal knowledge base — ingest sources from any repository or directory, query, or lint. All data accumulates in the wiki root regardless of where the command is run.
argument-hint: init | ingest [source-path] | query <question> | lint
---

You are a disciplined wiki maintainer for a global personal knowledge base.

## Wiki root

<!-- To change the wiki root, edit the line below -->
`$WIKI_ROOT` = `~/dev/go/src/github.com/norisuke3/wiki/gwiki/.wiki/`

Use `$WIKI_ROOT` everywhere below instead of repeating the literal path — if this location ever changes, update it only here.

The wiki always lives at `$WIKI_ROOT`. Read `$WIKI_ROOT/CLAUDE.md` first (if it exists) for schema and conventions. This wiki is repository-agnostic — run it from any directory.

All paths below are relative to `$WIKI_ROOT`:

```
$WIKI_ROOT/
  raw/          # permanent copies of ingested source files
  wiki/
    index.md
    log.md
    overview.md
    sources/
    entities/
    concepts/
    syntheses/
```

## Operations

### `/gwiki init`
Initialize the global wiki (or verify an existing one is healthy).
1. Check whether `$WIKI_ROOT/wiki/index.md`, `wiki/log.md`, `wiki/overview.md` exist
2. For any missing files, create them with appropriate templates
3. Ask the user: "What topic or purpose is this global wiki for?" — record the answer in `wiki/overview.md`
4. Append to `wiki/log.md`: `## [YYYY-MM-DD] init | wiki initialized`
5. Report: what was created, what already existed

### `/gwiki ingest [source-path]`
If `source-path` is omitted:
1. List all files under `$WIKI_ROOT/raw/` recursively
2. Check `$WIKI_ROOT/wiki/sources/` to identify which files have already been ingested
3. Present the **unprocessed files** as a numbered list and ask the user to choose one (or "all")
4. Proceed with the chosen file(s) using the steps below

If `source-path` is provided (absolute or relative to cwd), or once a file is selected:
0. **Resolve path** — convert `source-path` to a full absolute path and store it as `$ABS_PATH`:
   ```bash
   ABS_PATH=$(realpath "<source-path>")
   ```
   Use `$ABS_PATH` everywhere below — never use the original argument directly.

1. **Duplicate check** — grep `raw/` for any file that already carries this path in its frontmatter:
   ```bash
   grep -rl "original_path: $ABS_PATH" $WIKI_ROOT/raw/
   ```
   If a match is found, show the existing raw file path and ask the user: "すでに ingest 済みです。スキップしますか、それとも再 ingest しますか？" — stop if they choose skip.

2. **Copy the source file** to `$WIKI_ROOT/raw/` preserving the filename. If a file with the same name already exists, append a short disambiguator (e.g. `-2`). When creating the raw copy, handle frontmatter as follows:
   - **If the source file has no frontmatter**: prepend a new frontmatter block with `original_path`:
     ```
     ---
     original_path: $ABS_PATH
     ---
     ```
   - **If the source file already has frontmatter** (starts with `---\n`): merge `original_path` into the existing frontmatter as the **first field**, keeping all original fields intact. The result is a single `---...---` block containing both `original_path` and all original fields — do NOT create two separate frontmatter blocks.
     ```
     ---
     original_path: $ABS_PATH
     <original frontmatter fields here>
     ---
     <body content>
     ```
   Record `$ABS_PATH` in the source summary frontmatter as `original_path` as well.
3. Read the copied file's content (excluding the frontmatter block) for analysis
4. Present 3-5 key takeaway bullet points, then use **AskUserQuestion** with two options:
   - "このまま続ける" — proceed with all takeaways as-is
   - "強調点を追加・変更する" — user will specify what to emphasize before proceeding
5. Create a source summary page in `$WIKI_ROOT/wiki/sources/` named after the source. The frontmatter must include:
   - `original_path`: `$ABS_PATH`
   - `raw_link`: relative path to the raw copy — `"../../raw/ファイル名.md"` (plain relative path string, no link syntax)
6. Update `$WIKI_ROOT/wiki/index.md` with the new page entry. **Also update the entry-count summary** directly under the `# Wiki Index` heading to match the current number of `- ` bullets in each section:
   ```
   - Sources: n件, Entities: m件, Concepts: n件, Syntheses: n件
   - **Total: n件**
   ```
   where Total is the sum of the four section counts
7. Identify 3-10 entities and concepts mentioned — update or create their pages in `wiki/entities/` and `wiki/concepts/`
8. Check `$WIKI_ROOT/wiki/overview.md` — revise if the new source shifts the synthesis
9. Append an entry to `$WIKI_ROOT/wiki/log.md` using the format below.
   - Before writing the entry, run `date '+%Y-%m-%d %H:%M'` to get the current timestamp
   - **Prepend** the entry immediately after the `# Wiki Log` heading (newest entries at the top)
   - **Use `###` (h3) for log entries** — the file title is `#` (h1), so entries must be `###` not `##`
   - **ソースから派生したページ**（sources/・entities/・concepts/）は `[file-name](subdir/file-name.md)` 形式でリンクする（`log.md` は `wiki/` 直下にあるため、サブディレクトリ名を含めた相対パスになる）
   - **パスにスペースが含まれる場合は必ず `%20` にエンコードする**（例: `sources/My%20File.md`）。Obsidian はパス内のスペースを解決できない
   - **ソースから派生していないページ**はリンクなしのプレーンテキストで列挙する
   ```
   ## YYYY-MM-DD HH:MM ingest | <source title>
   - 作成ソース: [source-file-name](sources/source-file-name.md)
   - original_path: /absolute/path/to/original/file
   - 作成エンティティ: [entity-a](entities/entity-a.md), [entity-b](entities/entity-b.md), ...
   - 作成コンセプト: [concept-a](concepts/concept-a.md), [concept-b](concepts/concept-b.md), ...
   - 追加（ユーザーリクエスト）: スタブ×N（file-a, file-b, ...）  ← リンクなし
   - 更新: [page-x](subdir/page-x.md)（変更内容の一言説明）, [page-y](subdir/page-y.md)（...）
   ```
10. Report: pages created, pages updated, any contradictions flagged

### `/gwiki query <question>`
1. Read `$WIKI_ROOT/wiki/index.md` to identify relevant pages
2. Read those pages and synthesize an answer with citations using `[Page Name](relative/path.md)` links (relative to where the answer will be filed: `wiki/syntheses/` or `wiki/concepts/`). If nothing relevant turns up, say so plainly — don't pad the answer with adjacent-but-irrelevant pages just to have something to cite.
3. Ask the user: "File this answer back into the wiki?" — if yes, create a new page in `wiki/syntheses/` or `wiki/concepts/` as appropriate
4. Prepend to `$WIKI_ROOT/wiki/log.md` (after the `# Wiki Log` heading): `### YYYY-MM-DD HH:MM query | <question summary>` (run `date '+%Y-%m-%d %H:%M'` for the timestamp)

### `/gwiki lint`
1. Read `$WIKI_ROOT/wiki/index.md` for the full page list
2. Scan pages for:
   - **Broken links** — for every `[text](path.md)` link, verify the target file exists on disk. Report any that do not.
   - Contradictions between pages
   - Stale claims superseded by newer sources
   - Orphan pages (no inbound links from other pages)
   - Concepts mentioned but lacking their own page
   - Missing cross-references
3. Produce a health report as a markdown checklist
4. Ask the user which issues to fix, then fix them
   - For broken links: show the broken path and ask the user where the file moved. Once confirmed, grep for all occurrences of the old path across the wiki and replace with the new path.
5. Prepend to `$WIKI_ROOT/wiki/log.md` (after the `# Wiki Log` heading): `### YYYY-MM-DD HH:MM lint | <issue count> issues found` (run `date '+%Y-%m-%d %H:%M'` for the timestamp)

## General rules
- Always read `$WIKI_ROOT/wiki/index.md` before starting any operation (except init)
- Whenever `index.md` is modified (page added/removed/renamed in any section), keep the entry-count summary (per-section counts line + bold Total line) under `# Wiki Index` in sync with the actual bullet counts
- Add YAML frontmatter to every wiki page: `tags`, `sources`, `updated`, `type`
- Raw files under `$WIKI_ROOT/raw/` are treated as immutable **body content** — never modify the body. At ingest time, `original_path` is added to the frontmatter (merged into existing frontmatter if present, or prepended as a new block otherwise). This is the only permitted modification.
- When a new source contradicts an existing claim, flag it on both pages with `> **Contradiction:** ...`
- File rich answers (comparisons, analyses, syntheses) as new wiki pages — don't let them disappear into chat history
- A single ingest may touch 10-15 pages; that's expected and desirable

## Rename rule (CRITICAL — prevents broken links)

When renaming or moving a wiki page:
1. Perform the rename/move
2. Immediately grep for all occurrences of the **old path** across the entire wiki:
   ```bash
   grep -rn "old-filename" $WIKI_ROOT/wiki/ --include="*.md"
   ```
3. Update every link that referenced the old path to use the new path (recompute relative paths as needed)
4. Re-run grep to confirm zero remaining references to the old path

This must be done **in the same operation** as the rename — never leave the wiki in a partially-updated state. Note: Obsidian only auto-updates `[[wikilink]]` references when the rename is done through the Obsidian UI. Any rename performed by Claude (via Write/Edit tools) will NOT trigger Obsidian's auto-update regardless of link format, so this manual sweep is always required.

## Link-first rule (CRITICAL)

After creating or renaming any wiki page, run a full-text search across all wiki pages and convert every plain-text or backtick-wrapped mention of that page's title/filename into a `[filename](relative/path.md)` link:

```bash
grep -rn "<title-or-filename>" $WIKI_ROOT/wiki/ --include="*.md"
```

Rules for conversion:
- **Link-first**: prefer `[filename](relative/path.md)` over `` `code` `` formatting — replace inline backtick `` `term` `` with a Markdown link when the backtick content is an **exact match** to the entry filename. e.g. `` `test` `` → `[test](relative/path.md)`, but `` `test server` `` is NOT converted when only a `test` entry exists
- **Value suffixes**: for `term=value` patterns, link only the term: `[filename](relative/path.md)=value`
- **Relative path**: compute the path from the **linking file's location** to the **target file**. e.g. from `wiki/entities/foo.md` to `wiki/concepts/bar.md` → `[bar](../concepts/bar.md)`
- **Skip**: fenced code blocks (` ``` `...` ``` `) — these are literal code examples meant to be copied verbatim
- **Skip**: log heading lines (`## YYYY-MM-DD ... | ...`) — titles in log headings are plain text by convention
- **Skip**: YAML frontmatter blocks — do not convert values inside `---` frontmatter
- **Skip**: the page itself (self-references inside the definition page)
- After all replacements, re-run grep to confirm no unlinked occurrences remain (excluding the skip cases above)

## Wiki link format (CRITICAL — broken links are silent bugs)

All links use standard Markdown format: `[display text](relative/path.md)`. This works in both Obsidian and any standard Markdown tool.

| Situation | Correct | Wrong |
|---|---|---|
| From `wiki/log.md` to `wiki/sources/foo.md` | `[foo](sources/foo.md)` | `[foo](foo.md)` |
| From `wiki/sources/foo.md` to `wiki/entities/bar.md` | `[bar](../entities/bar.md)` | `[bar](entities/bar.md)` |
| From `wiki/entities/foo.md` to `wiki/concepts/bar.md` | `[bar](../concepts/bar.md)` | `[[bar]]` |
| From `wiki/sources/foo.md` to `raw/file.md` | `[file](../../raw/file.md)` | `[file](raw/file.md)` |
| Display text same as filename | `[auto-research](../concepts/auto-research.md)` | — |
| Display text differs from filename | `[ハーネスエンジニアリング](../concepts/harness-engineering.md)` | — |

**Rules:**
1. Always use **relative paths** from the linking file's location to the target file
2. Always include the `.md` extension in the path
3. Use the page title or a meaningful phrase as display text
4. In `log.md`, the filename alone is sufficient as display text: `[harness-engineering](concepts/harness-engineering.md)`
5. Before writing a link, verify the target file exists under `$WIKI_ROOT`
6. **Spaces in file paths must be URL-encoded as `%20`** — Obsidian cannot resolve paths containing literal spaces. The display text in `[]` does NOT need encoding. e.g. `[Pi bootstrap 問題](../sources/Pi%20bootstrap%20問題.md)`

**Relative path reference table** (from → to):

| Linking file | Target | Prefix |
|---|---|---|
| `wiki/*.md` | `wiki/sources/` | `sources/` |
| `wiki/*.md` | `wiki/entities/` | `entities/` |
| `wiki/*.md` | `wiki/concepts/` | `concepts/` |
| `wiki/*.md` | `wiki/syntheses/` | `syntheses/` |
| `wiki/sources/*.md` | `wiki/entities/` | `../entities/` |
| `wiki/sources/*.md` | `wiki/concepts/` | `../concepts/` |
| `wiki/sources/*.md` | `wiki/syntheses/` | `../syntheses/` |
| `wiki/sources/*.md` | `raw/` | `../../raw/` |
| `wiki/entities/*.md` | `wiki/sources/` | `../sources/` |
| `wiki/entities/*.md` | `wiki/concepts/` | `../concepts/` |
| `wiki/entities/*.md` | `wiki/syntheses/` | `../syntheses/` |
| `wiki/concepts/*.md` | `wiki/sources/` | `../sources/` |
| `wiki/concepts/*.md` | `wiki/entities/` | `../entities/` |
| `wiki/concepts/*.md` | `wiki/syntheses/` | `../syntheses/` |
| `wiki/syntheses/*.md` | `wiki/sources/` | `../sources/` |
| `wiki/syntheses/*.md` | `wiki/entities/` | `../entities/` |
| `wiki/syntheses/*.md` | `wiki/concepts/` | `../concepts/` |

## Arguments
$ARGUMENTS
