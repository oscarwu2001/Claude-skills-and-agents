---
name: system-map
description: "Turn a codebase or a system description into a polished, interactive system map published as an Artifact — authored lanes, labelled edges, click-to-inspect nodes. Use when the user asks for a system map, architecture diagram, component map, dependency map, or wants to visualise how a system fits together. Prefers verified edges from graphify-out/graph.json when one exists."
---

# /system-map

Turn a codebase or a system description into one interactive map the reader can
actually use: authored lanes, labelled edges, a node you can click to see what it
is and what touches it.

## Usage

```
/system-map                        # map the current project
/system-map <path>                 # map a subtree
/system-map "the shape-first route"  # map a system described in docs, not code
/system-map --from-docs <file>     # map what a design doc describes
/system-map --update <url>         # republish an existing map with new data
```

## How this sits with the other skills

This skill **draws**. It does not answer questions, own the palette, or chart
quantities. Precedence, so it never competes:

| The user … | Goes to | Because |
|---|---|---|
| asks *how does X work*, *what calls Y* | **graphify** | a question wants a sentence; a map is a slow way to say one |
| asks for a map, diagram, or "show me the architecture" | **this skill** | which then *queries* graphify for its edges |
| needs one claim made visible — a mechanism, a before/after | **artifact-diagramming** | a static figure argues; a map lets you look things up |
| needs a palette and type | **artifact-design** | load it before building; this skill never sets a palette |
| needs quantities plotted | **dataviz** | a chart is not a map |

`graphify` is the read layer, not a rival: an architecture *question* is a
graphify query first, and stays one. This skill fires only when the deliverable
is a picture, and then graphify supplies the verified edges that go in it.

**One deliberate departure.** `artifact-diagramming` requires static,
hand-authored SVG with no runtime. This skill's template builds its SVG from a
JS data array instead, because click-to-inspect, filtering and search *are* the
reason an interactive map exists. The script stays outside the `<svg>` element
and the map renders on load, so the page is still complete at rest. For any
static figure on the same page, `artifact-diagramming`'s rule applies unchanged.

## The one rule

**A system map is curated, never dumped.**

Every auto-generated graph fails the same way: 301 nodes in a force-directed
blob that nobody can read. Graphify already produces that view and it is useful
for *searching*, not for *understanding*. This skill produces the other thing —
the 8 to 25 nodes that carry the argument, placed on purpose.

If you cannot say what a node is doing in the map, it is not in the map.

Corollaries:

- **Positions are authored, not simulated.** No force-directed layout, ever. The
  template's lane/row grid computes coordinates for you — your job is to decide
  which lane and which row, and that decision *is* the diagram.
- **Every edge carries a verb.** `calls`, `writes`, `invalidates`, `polls every
  30s`. An unlabelled arrow means "related somehow", which the prose already said.
- **Aggregate ruthlessly.** Twelve sibling scripts become one node called
  "survey scripts" with a count. The reader wants the shape, not the inventory.

## Process

### Step 1 — Decide what the map is about

Ask yourself what a reader should be able to *do* with it. The answer sets the
scope, and the scope sets which nodes exist. Common answers:

| The reader wants to | So the map shows |
|---|---|
| Know where to make a change | Seams, and what each one's blast radius is |
| Understand a data flow | The path one piece of data takes, end to end |
| Compare two designs | Both, aligned, with the differing edges emphasised |
| Onboard onto a system | Layers and their boundaries, not every module |

One map, one job. A second job is a second map on the same page.

### Step 2 — Gather the nodes and edges

**If `graphify-out/graph.json` exists** (check first — it is the cheapest source
of *verified* edges):

```bash
python3 -c "
import json, collections
g = json.load(open('graphify-out/graph.json', encoding='utf-8'))
deg = collections.Counter()
for l in g['links']:
    deg[l['source']] += 1; deg[l['target']] += 1
by_id = {n['id']: n for n in g['nodes']}
print('commit:', g.get('built_at_commit'))
for nid, d in deg.most_common(30):
    n = by_id.get(nid, {})
    print(f\"{d:3d}  {n.get('label','?'):32s} {n.get('source_file','')}:{n.get('source_location','')}\")
"
```

Read `graphify-out/GRAPH_REPORT.md` too — its **God Nodes** list is the
candidate set for your map's nodes, and its **Communities** are candidate lanes.

Check freshness before trusting it: compare `built_at_commit` to `git rev-parse
HEAD`. If it is stale, say so on the page rather than silently drawing an old
system. Offer `graphify update .` (free, no API cost).

Pull edges from `graph.json` rather than from memory — an edge with
`confidence: "EXTRACTED"` is AST-derived and true; `INFERRED` is a heuristic
guess and should be drawn dashed or left out.

**If there is no graph**, read the code or the doc directly. Prefer the
project's own architecture docs (CONTEXT.md, README, ADRs, plan docs) — they
name the parts the way the team names them, which is the naming the map must
use.

**If the subject is a described system rather than code** (a plan, a proposed
route, a pipeline that does not exist yet), there is nothing to extract: the
nodes come from the document, and your job is fidelity to what it says,
including what it marks as unbuilt.

### Step 3 — Lay it out

Assign every node a **lane** (a column, or a horizontal band — the template does
both) and a **row** within it. Lanes should encode something true: pipeline
stage, architectural layer, trust boundary, sim vs real, built vs proposed.

A lane that means nothing is worse than no lanes.

Then mark node **kind** — the template styles these differently:

- `primary` — the thing the map is about
- `normal` — supporting parts
- `external` — outside the system's control
- `proposed` — not built yet
- `problem` — where the thing being discussed goes wrong

Use `problem` and `proposed` sparingly; they are the page's emphasis and spend
their force if everything wears them.

### Step 4 — Build the page

Read `references/template.html` and adapt it. It is a working page: a
lane/row grid that computes SVG coordinates, orthogonal edge routing, a detail
panel, lane filters, search, and keyboard navigation. **You fill in the `NODES`
and `EDGES` arrays and the lane definitions; you do not hand-author
coordinates.**

Before writing the file, load the **`artifact-design`** skill — it owns palette,
typography, and the light/dark token discipline. This skill owns structure and
interaction; that one owns how it looks. Where the project has its own visual
language (an existing artifact, a design doc), match it instead.

If the page also needs a *static* figure — a mechanism, a comparison, a
before/after — load **`artifact-diagramming`** for that figure. An interactive
map and an explanatory figure do different jobs and a good page often has both.

### Step 5 — Publish and hand over the link

Publish with the `Artifact` tool. Give it a name that is a name, not a
category: "Ingest and Review", not "System Architecture Diagram".

Then say, in the chat, the two or three things the map makes visible that prose
would not — a cycle, a seam with eleven callers, a hop nothing tests. **That
sentence is the deliverable.** The map is how the reader checks it.

## Interaction the template already implements

Do not add interaction beyond this without a reason; each item below earns its
place by answering a question a static picture cannot.

| Interaction | Answers |
|---|---|
| Click a node | "What is this, and where does it live?" |
| Node focus dims the rest | "What does this actually touch?" |
| Lane filter | "Show me just the data layer" |
| Search | "Where is `select_series` in here?" |
| Edge hover | "What does this arrow mean?" |

Keyboard: Tab reaches every node, Enter or Space opens the panel, Escape clears
the selection. The template handles this — keep it working.

## Failure modes to avoid

- **The hairball.** More than ~25 nodes and the map stops being a map. Aggregate
  or split into two maps.
- **Lanes that don't mean anything.** If you cannot name the lane in two words,
  the grouping is wrong.
- **Unlabelled edges.** Every arrow gets a verb.
- **Drawing from memory.** If a graph or the code is available, the edges come
  from there. A confidently wrong arrow is worse than a missing one.
- **Decorative interactivity.** Pan-and-zoom on a 12-node map is friction, not a
  feature. The template's map fits its frame by design.
- **Silent staleness.** If the source graph is behind HEAD, the page says so.

## Checklist before publishing

- [ ] Every node earns its place; count is under 25
- [ ] Every edge has a verb
- [ ] Lanes encode something true and are named
- [ ] Inferred or uncertain edges are visually distinct from verified ones
- [ ] The page states its source and, if relevant, its freshness
- [ ] Works in light and dark; nothing is defined only inside a media query
- [ ] Keyboard reaches every node; focus is visible
- [ ] The map fits its frame at 1280px and scrolls in its own container below that
