#!/usr/bin/env bash
# Sync a wiki's description into its own wiki/index.md and into the
# star-network registry (~/.claude/wiki-registry.md by default).
#
# Usage:
#   wiki-sync-description.sh [--create] <wiki-root>   # description text via stdin
#
#   --create   also create a new registry entry if this wiki isn't registered
#              yet (used by `/wiki register`). Without it, if the wiki has no
#              existing registry entry, the registry is left untouched (used
#              by the ingest-time incremental description check, which must
#              never silently join a wiki to the network).
#
# The wiki's own wiki/index.md **Description:** block is always updated,
# regardless of --create or network membership.
set -euo pipefail

CREATE=0
if [[ "${1:-}" == "--create" ]]; then
  CREATE=1
  shift
fi

WIKI_ROOT="${1:?usage: wiki-sync-description.sh [--create] <wiki-root>  (description text via stdin)}"
WIKI_ROOT="$(cd "$WIKI_ROOT" && pwd)"
REGISTRY="${WIKI_REGISTRY:-$HOME/.claude/wiki-registry.md}"
INDEX_MD="$WIKI_ROOT/wiki/index.md"

if [[ ! -f "$INDEX_MD" ]]; then
  echo "error: $INDEX_MD not found" >&2
  exit 1
fi

DESCRIPTION="$(cat)"
if [[ -z "$DESCRIPTION" ]]; then
  echo "error: description text (stdin) is empty" >&2
  exit 1
fi

TODAY="$(date '+%Y-%m-%d')"

WIKI_ROOT="$WIKI_ROOT" INDEX_MD="$INDEX_MD" REGISTRY="$REGISTRY" \
DESCRIPTION="$DESCRIPTION" TODAY="$TODAY" CREATE="$CREATE" \
python3 - <<'PYEOF'
import os, re, sys

wiki_root = os.environ["WIKI_ROOT"]
index_md = os.environ["INDEX_MD"]
registry = os.environ["REGISTRY"]
description = os.environ["DESCRIPTION"].rstrip("\n")
today = os.environ["TODAY"]
create = os.environ["CREATE"] == "1"


def update_index(path, description):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    desc_block = f"**Description:**\n{description}"
    if "**Description:**" in content:
        pattern = re.compile(r"\*\*Description:\*\*\n(?:.*\n)*?(?=\n)", re.MULTILINE)
        new_content, n = pattern.subn(desc_block + "\n", content, count=1)
        if n == 0:
            pattern2 = re.compile(r"\*\*Description:\*\*\n(?:.*\n?)*", re.MULTILINE)
            new_content = pattern2.sub(desc_block + "\n", content, count=1)
        content = new_content
    else:
        lines = content.split("\n")
        heading_idx = None
        for i, line in enumerate(lines):
            if line.startswith("# "):
                heading_idx = i
                break
        if heading_idx is None:
            raise SystemExit("error: no top-level heading found in index.md")
        insert_at = heading_idx + 1
        lines[insert_at:insert_at] = ["", desc_block, ""]
        content = "\n".join(lines)
    content = re.sub(r"\n{3,}", "\n\n", content)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def update_registry(path, wiki_root, description, today, create):
    if not os.path.exists(path):
        if not create:
            print(f"warn: registry {path} does not exist and --create not set; skipping registry update", file=sys.stderr)
            return False
        with open(path, "w", encoding="utf-8") as f:
            f.write("# Wiki Registry\n")

    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    indented_desc = "\n".join(("  " + line if line else "") for line in description.split("\n"))
    name = os.path.basename(wiki_root.rstrip("/"))
    if name == ".wiki":
        name = os.path.basename(os.path.dirname(wiki_root.rstrip("/")))
    new_block = (
        f"## {name}\n"
        f"- path: {wiki_root}\n"
        f"- updated: {today}\n"
        f"- description:\n"
        f"{indented_desc}\n"
    )

    blocks = re.split(r"(?m)^(?=## )", content)
    if blocks and not blocks[0].startswith("## "):
        header = blocks[0]
        entry_blocks = blocks[1:]
    else:
        header = "# Wiki Registry\n\n"
        entry_blocks = blocks

    found = False
    out_blocks = []
    for b in entry_blocks:
        if re.search(rf"^- path: {re.escape(wiki_root)}\s*$", b, re.MULTILINE):
            out_blocks.append(new_block)
            found = True
        else:
            out_blocks.append(b)

    if not found:
        if not create:
            print(f"warn: wiki '{wiki_root}' not registered in {path}; run /wiki register first. Skipping registry update.", file=sys.stderr)
            return False
        out_blocks.append(new_block)

    body = "\n".join((b.rstrip("\n") + "\n") for b in out_blocks)
    new_content = header.rstrip("\n") + "\n\n" + body
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_content.rstrip("\n") + "\n")
    return True


update_index(index_md, description)
ok = update_registry(registry, wiki_root, description, today, create)
print(f"index.md updated: {index_md}")
print(f"registry {'updated' if ok else 'skipped'}: {registry}")
PYEOF
