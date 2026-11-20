// status-colors: cmux 公式 workspaces テンプレートをベースに、行へエージェント状態の色帯とバッジを追加したもの。
// Dia-style workspace sidebar: groups, cross-group drag, full context menus.
//
// The whole sidebar is ONE flat drag surface: group headers and workspace
// rows live in a single Reorderable. Headers are `fixed` (not grabbable, but
// they shift to open gaps like any row), so a workspace can be dragged
// between groups, into a group, or out to the ungrouped area in one gesture.
// The drop resolves to (container group, reorder anchor) from the flat index
// and dispatches workspace.group.add/remove + workspace.reorder.
//
// Group collapse is optimistic (a local signal flips instantly) and syncs via
// workspace.group.collapse/expand so the built-in sidebar agrees.
//
// Open:     cmux sidebar open workspaces

// --- optimistic UI -------------------------------------------------------------
// Every user action flips local state the same frame; the cmux command runs
// behind it and the authoritative data context (which refreshes about once a
// second) reconciles: each override clears itself as soon as the data agrees.
let selectOverride = null;
const [selectTick, setSelectTick] = signal(0);

function isSelected(w) {
  selectTick();
  if (!w) return false;
  if (selectOverride) {
    if (data.selectedId() === selectOverride) selectOverride = null; // caught up
    else return w.id === selectOverride;
  }
  return !!w.selected;
}

function selectWorkspace(id) {
  if (!id) return;
  selectOverride = id;
  setSelectTick(selectTick() + 1);
  cmux("workspace.select", { workspace_id: id });
}

const closedOverride = new Set();
const [closeTick, setCloseTick] = signal(0);

// Optimistic tabs order: a bulk drop rearranges rows locally the same frame
// (reorder_many echoes ~1s later); clears itself once the data agrees.
let orderOverride = null;
const [orderTick, setOrderTick] = signal(0);

function setOrderOverride(ids) {
  orderOverride = ids;
  setOrderTick(orderTick() + 1);
}

function visibleWorkspaces() {
  closeTick();
  orderTick();
  let ws = data.workspaces() ?? [];
  for (const id of Array.from(closedOverride)) {
    if (!ws.some((w) => w.id === id)) closedOverride.delete(id); // caught up
  }
  ws = ws.filter((w) => !closedOverride.has(w.id));
  if (orderOverride) {
    const actual = ws.map((w) => w.id).join(",");
    const wanted = orderOverride.filter((id) => ws.some((w) => w.id === id)).join(",");
    if (actual === wanted) {
      orderOverride = null; // caught up
    } else {
      const rank = new Map(orderOverride.map((id, i) => [id, i]));
      ws = [...ws].sort((a, b) => (rank.get(a.id) ?? 1e9) - (rank.get(b.id) ?? 1e9));
    }
  }
  return ws;
}

function closeWorkspace(id) {
  closedOverride.add(id);
  setCloseTick(closeTick() + 1);
  cmux("workspace.close", { workspace_id: id });
}

// Multi-select: Cmd-click toggles, Shift-click extends from the last click
// over the visible row order, plain click clears. The selection drives the
// context menu's bulk actions (group together, move, close).
const multiSelected = new Set();
const [multiTick, setMultiTick] = signal(0);
let lastClickedId = null;

function isMultiSelected(w) {
  multiTick();
  return !!w && multiSelected.has(w.id);
}

function clearMultiSelect() {
  if (multiSelected.size === 0) return;
  multiSelected.clear();
  setMultiTick(multiTick() + 1);
}

function visibleRowIds() {
  return flatEntries().filter((e) => e.kind === "ws").map((e) => e.wsId);
}

function handleRowClick(w, payload) {
  const id = w.id;
  if (payload && payload.cmd) {
    if (multiSelected.has(id)) multiSelected.delete(id);
    else multiSelected.add(id);
    setMultiTick(multiTick() + 1);
  } else if (payload && payload.shift && lastClickedId) {
    const order = visibleRowIds();
    const a = order.indexOf(lastClickedId);
    const b = order.indexOf(id);
    if (a >= 0 && b >= 0) {
      for (const rid of order.slice(Math.min(a, b), Math.max(a, b) + 1)) multiSelected.add(rid);
      setMultiTick(multiTick() + 1);
    }
  } else {
    clearMultiSelect();
    selectWorkspace(id);
  }
  lastClickedId = id;
}

// The set of workspaces a bulk menu action applies to: the multi-selection
// when the clicked row is part of it, else just the clicked row.
function bulkIds(w) {
  multiTick();
  if (w && multiSelected.has(w.id)) return Array.from(multiSelected);
  return w ? [w.id] : [];
}

const titleOverride = new Map();
const [titleTick, setTitleTick] = signal(0);

function displayTitle(w) {
  titleTick();
  if (!w) return "";
  if (titleOverride.has(w.id)) {
    const t = titleOverride.get(w.id);
    if (w.title === t) titleOverride.delete(w.id); // caught up
    else return t;
  }
  return w.title;
}

// --- inline rename -----------------------------------------------------------
// Double-click a row/header (or its Rename menu item) to edit in place.
// Editing swaps the entry's key, so the keyed reconciler remounts the row as
// an editor; Return commits through workspace(.group).rename, Escape cancels.
const [editingId, setEditingId] = signal(null);

// --- optimistic collapse -----------------------------------------------------
const collapseOverride = new Map();
const [collapseTick, setCollapseTick] = signal(0);

function isCollapsed(g) {
  collapseTick();
  if (collapseOverride.has(g.id)) {
    const v = collapseOverride.get(g.id);
    if (v === g.collapsed) collapseOverride.delete(g.id); // host caught up
    else return v;
  }
  return g.collapsed;
}

function toggleCollapse(g) {
  const next = !isCollapsed(g);
  collapseOverride.set(g.id, next);
  setCollapseTick(collapseTick() + 1);
  cmux(next ? "workspace.group.collapse" : "workspace.group.expand", { group_id: g.id });
}

// --- data helpers ------------------------------------------------------------
const groupById = (id) => (data.groups() ?? []).find((g) => g.id === id);
const membersOf = (id) => visibleWorkspaces().filter((w) => w.group === id);
// The anchor workspace IS the header (matching the built-in sidebar).
const memberRowsOf = (id) => {
  const g = groupById(id);
  return membersOf(id).filter((w) => !g || w.id !== g.anchorId);
};

// One flat entry list. A group renders (header + expanded member rows) at
// its ANCHOR's tabs position - the app's canonical block position - so a
// stray member sitting early in the tabs order can never yank the whole
// group upward. Pinned groups and pinned ungrouped workspaces float to a
// cluster at the top.
const flatEntries = computed(() => {
  const ws = visibleWorkspaces();
  const groups = new Map((data.groups() ?? []).map((g) => [g.id, g]));
  const editing = editingId();
  const wsEntry = (w, groupId) => ({
    kind: "ws",
    id: w.id + (editing === w.id ? ":edit" : ""),
    wsId: w.id,
    editing: editing === w.id,
    groupId,
  });
  const groupSection = (g) => {
    const out = [{
      kind: "header",
      id: "h:" + g.id + (editing === "h:" + g.id ? ":edit" : ""),
      groupId: g.id,
      editing: editing === "h:" + g.id,
    }];
    if (!isCollapsed(g)) {
      for (const m of memberRowsOf(g.id)) out.push(wsEntry(m, g.id));
    }
    return out;
  };

  const pinned = [];
  const rest = [];
  const seen = new Set();
  for (const w of ws) {
    if (w.group && groups.has(w.group)) {
      const g = groups.get(w.group);
      // Emit the group at its anchor's position; a group whose anchor is
      // hidden (optimistically closed) falls back to its first member.
      const isAnchor = w.id === g.anchorId || !ws.some((x) => x.id === g.anchorId);
      if (seen.has(g.id) || !isAnchor) continue;
      seen.add(g.id);
      (g.pinned ? pinned : rest).push(...groupSection(g));
    } else if (!w.group) {
      (w.pinned ? pinned : rest).push(wsEntry(w, null));
    }
  }
  // Groups whose anchor never appeared (edge churn): append at the end.
  for (const g of groups.values()) {
    if (!seen.has(g.id) && ws.some((x) => x.group === g.id)) {
      seen.add(g.id);
      (g.pinned ? pinned : rest).push(...groupSection(g));
    }
  }
  return [...pinned, ...rest];
});

// --- drop resolution ---------------------------------------------------------
// `index` is the dragged row's slot in the flat list (headers included).
// `extra.side` resolves the ambiguous boundary slots: "above" nests with the
// row above (e.g. last item of a group), "below" with the row below (right
// after the group, outside it) - chosen by the pointer's X position mid-drag.
// Dragging a group HEADER moves the whole block (extra.block).
function handleMove(id, index, extra) {
  // Use the order currently rendered, including optimistic reorder overrides.
  // The host-provided `index` fields can lag behind that view for one or more
  // frames after a bulk or group move.
  const ws = visibleWorkspaces();

  if (extra && extra.block && id.startsWith("h:")) {
    // Whole-group move. workspace.group.move is NOT usable here: its
    // to_index is a group-slot index (position among groups, clamped to the
    // pin tier), so a tabs index overshoots to "last group" and a drop
    // between ungrouped rows is unreachable. Instead send the full tabs
    // order with the block extracted and re-inserted contiguously (anchor
    // first) at the drop slot - the app's contiguity normalization keeps it.
    const gid = id.slice(2);
    const memberIds = new Set(membersOf(gid).map((w) => w.id));
    const entries = flatEntries().filter((e) => e.id !== id && e.groupId !== gid);
    // The next entry that stays put anchors the drop. A header counts too:
    // dropping right above a (possibly collapsed) group means "before its
    // anchor", not "after its hidden members".
    const nextEntry = entries.slice(index).find((e) => e.kind === "ws" || e.kind === "header");
    const nextId = nextEntry
      ? (nextEntry.kind === "header" ? groupById(nextEntry.groupId)?.anchorId : nextEntry.wsId)
      : null;
    const anchorId = groupById(gid)?.anchorId;
    const blockIds = ws.map((x) => x.id).filter((x) => memberIds.has(x));
    if (anchorId && blockIds.includes(anchorId)) {
      blockIds.splice(blockIds.indexOf(anchorId), 1);
      blockIds.unshift(anchorId);
    }
    const rest = ws.map((x) => x.id).filter((x) => !memberIds.has(x));
    let insertAt = nextId ? rest.indexOf(nextId) : rest.length;
    if (insertAt < 0) insertAt = rest.length;
    const full = [...rest.slice(0, insertAt), ...blockIds, ...rest.slice(insertAt)];
    setOrderOverride(full); // paint the new order now; reorder_many echoes behind it
    cmux("workspace.reorder_many", { workspace_ids: JSON.stringify(full) });
    return;
  }

  const dragged = ws.find((w) => w.id === id);
  if (!dragged) return;

  // Dragging a row that is part of the multi-selection moves the WHOLE
  // selection: the visible selected rows gather contiguously at the drop
  // slot (visual order preserved) and all take the slot's container. This is
  // the platform-standard resolution for non-contiguous selections and for
  // selections mixing in-group and ungrouped rows. Hidden rows (inside a
  // collapsed group) never move - what you see is what you drag.
  multiTick();
  const bulk = multiSelected.has(id) && multiSelected.size > 1;
  const movingIds = bulk
    ? visibleRowIds().filter((rid) => multiSelected.has(rid) || rid === id)
    : [id];
  const moving = new Set(movingIds);

  const entries = flatEntries().filter((e) => e.id !== id);
  // Neighbors that will NOT move: rows moving with the drag can't define the
  // drop's container or anchor.
  let prev = null;
  for (let i = index - 1; i >= 0; i -= 1) {
    const e = entries[i];
    if (e.kind === "ws" && moving.has(e.wsId ?? e.id)) continue;
    prev = e;
    break;
  }
  const stays = (e) => !(e.kind === "ws" && moving.has(e.wsId ?? e.id));
  // The drop's tabs-order anchor is the next entry that stays put. A header
  // resolves to its group's ANCHOR workspace: dropping above a group means
  // "before the whole block", never "between its anchor and members" (which
  // would break contiguity and get normalized somewhere else).
  const nextEntry = entries.slice(index).find((e) => {
    if (e.kind === "header") return !moving.has(groupById(e.groupId)?.anchorId);
    return e.kind === "ws" && stays(e);
  });
  const nextAny = entries.slice(index).find(stays) ?? null;
  const nextRefId = nextEntry
    ? (nextEntry.kind === "header" ? groupById(nextEntry.groupId)?.anchorId : (nextEntry.wsId ?? nextEntry.id))
    : null;
  const nextWorkspace = nextRefId ? ws.find((w) => w.id === nextRefId) : null;

  let container;
  if (extra && extra.side === "below") {
    // Nest with what's below: a header below means "above the next group",
    // i.e. ungrouped; a row below means its group (or ungrouped).
    container = nextAny && nextAny.kind === "ws" ? nextAny.groupId : null;
  } else {
    container = prev ? prev.groupId : null;
    // Dropping right below a collapsed group's header means "after the whole
    // group", not "into it" (its rows are hidden), unless it lives there.
    if (prev && prev.kind === "header") {
      const g = groupById(prev.groupId);
      if (g && isCollapsed(g) && dragged.group !== g.id) container = null;
    }
  }

  for (const rid of movingIds) {
    const row = ws.find((w) => w.id === rid);
    if (!row) continue;
    if ((row.group ?? null) !== container) {
      if (container) {
        cmux("workspace.group.add", { group_id: container, workspace_id: rid });
      } else {
        cmux("workspace.group.remove", { workspace_id: rid });
      }
    }
  }

  if (bulk) {
    // Atomic block placement: send the full tabs order with the moving rows
    // inserted contiguously before the anchor.
    const rest = ws.map((x) => x.id).filter((x) => !moving.has(x));
    let insertAt = nextWorkspace ? rest.indexOf(nextWorkspace.id) : rest.length;
    if (insertAt < 0) insertAt = rest.length;
    const full = [...rest.slice(0, insertAt), ...movingIds, ...rest.slice(insertAt)];
    setOrderOverride(full); // gather instantly; reorder_many echoes behind it
    cmux("workspace.reorder_many", { workspace_ids: JSON.stringify(full) });
    clearMultiSelect();
    return;
  }

  if (nextWorkspace) {
    const draggedPosition = ws.findIndex((w) => w.id === dragged.id);
    const before = ws.findIndex((w) => w.id === nextWorkspace.id);
    const target = draggedPosition < before ? before - 1 : before;
    cmux("workspace.reorder", { workspace_id: id, index: target });
  } else {
    cmux("workspace.reorder", { workspace_id: id, index: ws.length - 1 });
  }
  // Dragging an unselected row with a selection active clears the stale
  // selection (platform convention).
  clearMultiSelect();
}

// --- rows ----------------------------------------------------------------------
function workspaceMenu(w) {
  const act = (action) => () =>
    cmux("workspace.action", { action, workspace_id: w().id });
  const groupItems = (data.groups() ?? []).map((g) =>
    Button(() => (groupById(g.id)?.name ?? ""), () => {
      for (const id of bulkIds(w())) cmux("workspace.group.add", { group_id: g.id, workspace_id: id });
      clearMultiSelect();
    }));
  const count = () => bulkIds(w()).length;
  return [
    Button(() => (count() > 1 ? "New Group from " + count() + " Workspaces" : "New Group with This"), () => {
      cmux("workspace.group.create", {
        name: "New Group",
        child_workspace_ids: JSON.stringify(bulkIds(w())),
      });
      clearMultiSelect();
    }),
    Divider(),
    Button("Rename", () => setEditingId(w().id)),
    Button(() => (w()?.pinned ? "Unpin" : "Pin"), () =>
      cmux("workspace.action", { action: w()?.pinned ? "unpin" : "pin", workspace_id: w().id })),
    Button(() => (w()?.unread > 0 ? "Mark as Read" : "Mark as Unread"), () =>
      cmux("workspace.action", { action: w()?.unread > 0 ? "mark_read" : "mark_unread", workspace_id: w().id })),
    Divider(),
    Menu("Move", [
      Button("Move Up", act("move_up")),
      Button("Move Down", act("move_down")),
      Button("Move to Top", act("move_top")),
    ]),
    Menu("Move to Group", groupItems),
    Button("Remove from Group", () => cmux("workspace.group.remove", { workspace_id: w().id })),
    Divider(),
    Button("Close Others", act("close_others")).destructive(),
    Button(() => (count() > 1 ? "Close " + count() + " Workspaces" : "Close"), () => {
      for (const id of bulkIds(w())) closeWorkspace(id);
      clearMultiSelect();
    }).destructive(),
  ];
}

// --- agent state ---------------------------------------------------------------
// 入力待ち=オレンジ / 実行中=緑 / 完了(未確認)=青 / 空き=グレー。agents が無い版や状態でも
// ワークスペースの status レーン（needs-attention / working）で補う。
const STATES = {
  needs_input: { label: "入力待ち", color: "#FF9F0A", icon: "hand.raised.fill" },
  working:     { label: "実行中",   color: "#30D158", icon: "bolt.fill" },
  subagents:   { label: "裏で実行中", color: "#BF5AF2", icon: "person.2.fill" },
  shells:      { label: "シェル待ち", color: "#64D2FF", icon: "terminal.fill" },
  done:        { label: "完了",     color: "#0A84FF", icon: "checkmark.circle.fill" },
  idle:        { label: "空き",     color: "#8E8E93", icon: "moon.zzz.fill" },
};

// エージェント1つの状態。本体が待機でも裏で動いているものがあれば空きにはしない（終わると本体が再開する）。
//  - サブエージェント → subagents（Claude が裏で考えて作業している）
//  - バックグラウンドのシェルだけ → shells（Claude は手を止めてコマンドの終わりを待っているだけ）
// 本体も動いているなら、裏に何かいても working（実行中）を優先する。
// ~/.claude/hooks/cmux-subagents.sh が progress ラベルに載せる件数を読む。
// 形式 "裏 N件 実行中 · <panelId>=<サブ件数>/<待ちシェル件数>/<サーバー件数>/<メインの手が空いていれば1>,..."（status はサイドバーのデータに載らないため progress を使う）
// サーバー（ポートを LISTEN しているシェル）は終わらないので、状態には影響させず行の注記だけにする。
// cmux は裏でサブエージェントが動いている間、メインのターンが終わっても working のままにするので、
// フックが Stop で付けた「手が空いた」印があればそちらを信じる
function bgInfo(w) {
  const label = w?.progress?.label ?? "";
  const byPanel = {};
  const total = { subs: 0, shells: 0, servers: 0 };
  if (!label.startsWith("裏 ")) return { total, byPanel };
  for (const [, id, sub, sh, sv = "0", idle = "0"] of label.matchAll(/([0-9A-Fa-f-]{8,})=(\d+)\/(\d+)(?:\/(\d+))?(?:\/(\d+))?/g)) {
    byPanel[id] = { subs: Number(sub), shells: Number(sh), servers: Number(sv), idle: idle === "1" };
    total.subs += Number(sub);
    total.shells += Number(sh);
    total.servers += Number(sv);
  }
  return { total, byPanel };
}
// エージェント1つの裏の件数。サブは cmux が知っている children とフックの多い方
function agentBg(a, w) {
  const hook = bgInfo(w).byPanel[a.panelId] ?? { subs: 0, shells: 0, servers: 0 };
  return { subs: Math.max((a.children ?? []).filter((c) => c.running).length, hook.subs), shells: hook.shells, servers: hook.servers, idle: !!hook.idle };
}
const shellLabel = (n) => `シェル ${n}件待ち`;
const bgLabel = ({ subs, shells }) =>
  [subs > 0 ? `サブ ${subs}件` : "", shells > 0 ? `シェル ${shells}件` : ""].filter(Boolean).join(" · ") + " 実行中";
function agentKey(a, w) {
  if (a.status === "needs_input") return "needs_input";
  const bg = agentBg(a, w);
  if (a.status === "working" && !(bg.idle && bg.subs + bg.shells > 0)) return "working";
  if (bg.subs > 0) return "subagents";
  if (bg.shells > 0) return "shells";
  // 手が空いていても、結果を見ていない（ペインに未読がある）なら「完了」。見たら「空き」
  if (agentTab(w, a)?.hasUnread) return "done";
  return "idle";
}

const ORDER = ["needs_input", "working", "subagents", "shells", "done", "idle"];
// 同じペインで前に起動した Claude のセッションが ended にならず残ることがあるので、
// ペインごとに一番最近動いたものだけを残す
function liveAgents(w) {
  const latest = new Map();
  for (const a of w?.agents ?? []) {
    if (a.status === "ended") continue;
    const key = a.panelId ?? a.id;
    const cur = latest.get(key);
    if (!cur || (a.lastActivityAt ?? 0) > (cur.lastActivityAt ?? 0)) latest.set(key, a);
  }
  return [...latest.values()];
}

// ワークスペース全体の状態 = 一番緊急度の高いエージェントの状態。複数いれば件数を付ける。
function agentState(w) {
  if (!w) return null;
  const keys = liveAgents(w).map((a) => agentKey(a, w));
  const ws = bgInfo(w).total;
  // ペイン単位で対応が取れなくても、ワークスペース合計があれば裏で実行中扱い（本体が動いていれば実行中のまま）
  if (ws.subs + ws.shells > 0 && !keys.includes("needs_input") && !keys.includes("working")) {
    return ws.subs > 0 ? { ...STATES.subagents, label: bgLabel(ws) } : { ...STATES.shells, label: shellLabel(ws.shells) };
  }
  let key = ORDER.find((k) => keys.includes(k));
  if (!key) {
    if (w.status === "needs-attention") key = "needs_input";
    else if (w.status === "working") key = "working";
    else return null;
  }
  if (key === "subagents" || key === "shells") {
    const sum = liveAgents(w).reduce((t, a) => { const b = agentBg(a, w); return { subs: t.subs + b.subs, shells: t.shells + b.shells }; }, { subs: 0, shells: 0 });
    return key === "subagents" ? { ...STATES.subagents, label: bgLabel(sum) } : { ...STATES.shells, label: shellLabel(sum.shells) };
  }
  const n = keys.filter((k) => k === key).length;
  return { ...STATES[key], label: n > 1 ? `${STATES[key].label} ${n}` : STATES[key].label };
}

// メインのバッジの横に出す「完了 N」「空き N」。他のペインが動いている間も、
// タスクを投げられるペインがあることが一覧で分かるようにする
function sideStates(w) {
  const main = agentState(w);
  if (!main) return [];
  return ["done", "idle"]
    .filter((k) => STATES[k].icon !== main.icon)
    .map((k) => ({ key: k, n: liveAgents(w).filter((a) => agentKey(a, w) === k).length }))
    .filter((e) => e.n > 0)
    .map((e) => ({ ...STATES[e.key], key: e.key, label: `${STATES[e.key].label} ${e.n}` }));
}

// エージェントが動いているペインのタブ名（なければ最初のプロンプト / エージェント名）
const agentTab = (w, a) => (w?.tabs ?? []).find((t) => t.id === a.panelId);
function agentTitle(w, a) {
  const tab = agentTab(w, a);
  return tab?.title || a.title || a.name || a.kind;
}

// 完了・空き・裏で実行中のペインはタブ名が前のタスクのままなので、頭に状態を付ける
function agentRowText(w, a) {
  const k = agentKey(a, w);
  const t = agentTitle(w, a);
  const sv = agentBg(a, w).servers;
  if (k === "done" || k === "idle") return `${STATES[k].label}${sv > 0 ? ` · サーバー ${sv}` : ""} · ${t}`;
  if (k === "subagents") return `${bgLabel(agentBg(a, w)).replace(/ 実行中$/, "")} · ${t}`;
  if (k === "shells") return `${shellLabel(agentBg(a, w).shells)} · ${t}`;
  return t;
}

// エージェントが動いているペインへ移動する。
// agents[].surfaceId は surface.focus で not_found になるため、実際の surface ID と一致する panelId を使う
function focusAgent(w, a) {
  cmux("surface.focus", { surface_id: a.panelId, workspace_id: w.id });
}

const shortDir = (d) => (d ?? "").replace(/^\/Users\/[^/]+/, "~");

const baseName = (d) => (d ?? "").replace(/\/+$/, "").split("/").pop();

// worktree（vibe が作る <repo>-<branch> 形式）にいるときは元のリポジトリ名を出す
const WORKTREE_SUFFIX = /-(feature|feat|fix|hotfix|chore|refactor|docs|test|release|renovate|dependabot)-.+$/;
function dirName(w) {
  const name = baseName(w?.directory);
  if (!name) return "";
  // ブランチ名を - でつないだものが末尾に付いていれば外す
  const slug = (w.branch ?? "").replace(/[^A-Za-z0-9._-]+/g, "-");
  if (slug && name.endsWith("-" + slug) && name.length > slug.length + 1) return name.slice(0, -(slug.length + 1));
  // 同じワークスペースの他のエージェントが元リポジトリにいれば、その名前を使う
  for (const a of w.agents ?? []) {
    const b = baseName(a.directory);
    if (b && b !== name && name.startsWith(b + "-")) return b;
  }
  return name.replace(WORKTREE_SUFFIX, "");
}

function subTitle(w) {
  const t = displayTitle(w);
  return t && t !== dirName(w) ? t : "";
}

// ディレクトリ名は1行目に出すので、ここはブランチと親ディレクトリだけ
function detailLine(w) {
  if (!w) return "";
  const branch = w.branch ? w.branch + (w.dirty ? "*" : "") : "";
  const parent = shortDir((w.directory ?? "").replace(/\/+$/, "").replace(/\/[^/]+$/, ""));
  return [branch, parent].filter(Boolean).join(" • ");
}

function extraLine(w) {
  if (!w) return "";
  const pr = w.pr ? `PR #${w.pr.number} ${w.pr.status === "merged" ? "マージ済み" : w.pr.status}` : "";
  const ports = (w.ports ?? []).slice(0, 5).map((p) => ":" + p).join(" ");
  return [pr, ports].filter(Boolean).join("  ");
}

function workspaceRow(w, entry) {
  const st = () => agentState(w());
  return ZStack({ alignment: "topTrailing" }, [
    HStack({ spacing: 8 }, [
      // 左端の色帯（状態色）
      RoundedRectangle({ cornerRadius: 2 })
        .fill(() => st()?.color ?? "clear")
        .frame({ width: 4, maxHeight: "infinity" }),
      VStack({ spacing: 3, alignment: "leading" }, [
        // 1行目: ディレクトリ名（一番目立たせる）
        HStack({ spacing: 0 }, [
          Text(() => dirName(w()) || displayTitle(w()))
            .font(14).weight("bold")
            .lineLimit(1).truncation("tail").marquee()
            .color(() => (isSelected(w()) ? "#FFFFFF" : "primary")),
          Spacer({ minLength: 24 }),
        ]),
        // 2行目: タブのタイトル（ディレクトリ名と同じなら出さない）
        HStack({ spacing: 0 }, [
          Text(() => subTitle(w()))
            .font(11).color("secondary")
            .lineLimit(1).truncation("tail"),
          Spacer({ minLength: 0 }),
        ]).frame(() => ({ height: subTitle(w()) ? 14 : 0 })),
        // 状態バッジ（色付きカプセル）
        HStack({ spacing: 4 }, [
          HStack({ spacing: 4 }, [
            Image(() => st()?.icon ?? "circle").font(10).color("#000000")
              .opacity(() => (st() ? 1 : 0)),
            Text(() => st()?.label ?? "").font(11).bold().color("#000000"),
          ])
            .paddingHorizontal(() => (st() ? 8 : 0))
            .paddingVertical(() => (st() ? 2 : 0))
            .background(() => st()?.color ?? null)
            .cornerRadius(9)
            .fixedSize()
            .opacity(() => (st() ? 1 : 0))
            .frame(() => ({ height: st() ? 18 : 0 })),
          // 完了・空きのペイン数（枠線だけのカプセル）
          ForEach(
            { items: () => sideStates(w()), key: (e) => e.key },
            (e) =>
              HStack({ spacing: 4 }, [
                Image(() => e().icon).font(10).color(() => e().color),
                Text(() => e().label).font(11).bold().color(() => e().color),
              ])
                .paddingHorizontal(7)
                .paddingVertical(1)
                .borderColor(() => e().color)
                .borderWidth(1)
                .cornerRadius(9)
                .fixedSize()
          ),
          Spacer(),
        ]),
        // 2ペイン以上でエージェントが動いているときは、エージェントごとの行を出す
        ForEach(
          { items: () => { const ag = liveAgents(w()); return ag.length >= 2 ? ag : []; }, key: (a) => a.id },
          (a) =>
            HStack({ spacing: 6 }, [
              // 空きは中抜きの丸、それ以外は状態色で塗る
              Circle({ size: 7 })
                .fill(() => (agentKey(a(), w()) === "idle" ? "clear" : STATES[agentKey(a(), w())].color))
                .stroke(() => STATES[agentKey(a(), w())].color)
                .strokeWidth(1.5),
              Text(() => agentRowText(w(), a())).font(11).color("secondary").lineLimit(1).truncation("tail")
                .opacity(() => (agentKey(a(), w()) === "idle" ? 0.6 : 1)),
              Spacer({ minLength: 0 }),
            ])
              .paddingVertical(1)
              .cornerRadius(4)
              .hoverBackground("#7f7f7f33")
              .cursor("pointer")
              .onTap(() => focusAgent(w(), a()))
        ),
        HStack({ spacing: 0 }, [
          Text(() => detailLine(w())).font(11).monospaced().color("secondary").lineLimit(1).truncation("middle"),
          Spacer({ minLength: 0 }),
        ]),
        HStack({ spacing: 0 }, [
          Text(() => extraLine(w())).font(11).monospaced()
            .color(() => (w()?.pr?.status === "merged" ? "#BF5AF2" : (w()?.pr?.status === "open" ? "#30D158" : "secondary")))
            .lineLimit(1),
          Spacer({ minLength: 0 }),
        ]).frame(() => ({ height: extraLine(w()) ? 14 : 0 })),
      ]),
    ]),
    // 右上: 未読バッジ / ピン / ホバー時の閉じるボタン（テンプレートと同じ）
    ZStack({}, [
      Text(() => (w()?.unread > 0 ? String(w().unread) : ""))
        .font("caption2").bold().color("white")
        .paddingHorizontal(() => (w()?.unread > 0 ? 5 : 0))
        .paddingVertical(() => (w()?.unread > 0 ? 1 : 0))
        .background(() => (w()?.unread > 0 ? "#E4573D" : null))
        .cornerRadius(7)
        .hideOnHover(),
      Image("pin.fill")
        .font(8).color("tertiary")
        .opacity(() => (w()?.pinned && !(w()?.unread > 0) ? 1 : 0))
        .hideOnHover(),
      Image("xmark")
        .font(9).weight("semibold").color("secondary")
        .padding(4)
        .cornerRadius(9)
        .hoverBackground("#7f7f7f4a")
        .showOnHover()
        .onTap(() => closeWorkspace(w().id)),
    ]),
  ])
    .paddingHorizontal(8)
    .paddingVertical(6)
    .marginLeading(() => (entry().groupId ? 14 : 0))
    .cornerRadius(8)
    // 選択中は青い背景+枠線でひと目で分かるようにする
    .background(() => (isMultiSelected(w()) ? "#4C9EEB33" : (isSelected(w()) ? "#4C8DFF40" : null)))
    .hoverBackground(() => (isMultiSelected(w()) ? "#4C9EEB33" : (isSelected(w()) ? "#4C8DFF40" : "#7f7f7f24")))
    .borderColor(() => (isSelected(w()) ? "#4C8DFF" : "clear"))
    .borderWidth(() => (isSelected(w()) ? 1.5 : 0))
    .frame({ maxWidth: "infinity" })
    .cursor("pointer")
    .block(() => (entry().groupId ? "h:" + entry().groupId : null))
    .dragSet(() => (isMultiSelected(w()) ? "multi" : null))
    .onTap((payload) => handleRowClick(w(), payload))
    .onDoubleTap(() => setEditingId(w().id))
    .contextMenu(workspaceMenu(w));
}

// In-place editor row (same box as a workspace row).
function workspaceEditRow(w, entry) {
  return HStack({ spacing: 8 }, [
    TextField(() => w()?.title ?? "", {
      placeholder: "Workspace name",
      onSubmit: (t) => {
        const title = (t ?? "").trim();
        if (title) {
          titleOverride.set(w().id, title);
          setTitleTick(titleTick() + 1);
          cmux("workspace.action", { action: "rename", workspace_id: w().id, title });
        } else {
          cmux("workspace.action", { action: "clear_name", workspace_id: w().id });
        }
        setEditingId(null);
      },
      onCancel: () => setEditingId(null),
    }).font(13),
  ])
    .paddingHorizontal(10)
    .paddingVertical(6)
    .cornerRadius(8)
    .background("#7f7f7f3d")
    .marginLeading(() => (entry().groupId ? 14 : 0))
    .frame({ maxWidth: "infinity" });
}

function groupHeader(groupId) {
  const g = () => groupById(groupId) ?? { id: groupId, name: "", collapsed: false, pinned: false };
  const anchor = () => (data.workspaces() ?? []).find((w) => w.id === g().anchorId);
  const groupAct = (action) => () =>
    cmux("workspace.group.action", { group_id: groupId, action });
  return HStack({ spacing: 6 }, [
    // The chevron toggles collapse; clicking anywhere else selects the
    // group's anchor workspace (built-in sidebar behavior). Chevron only,
    // no folder icon. One glyph that ROTATES (right -> down on expand):
    // rotation animates as one motion with the accordion, and the fixed box
    // keeps the header height constant.
    Image("chevron.right")
      .font(10).weight("semibold").color("tertiary")
      .rotation(() => (isCollapsed(g()) ? 0 : 90))
      .frame({ width: 14, height: 16 })
      .onTap(() => toggleCollapse(g())),
    Text(() => g().name).font(12).weight("semibold").lineLimit(1).truncation("tail")
      .color(() => (isSelected(anchor()) ? "primary" : "secondary")),
    Spacer(),
  ])
    .paddingLeading(8)
    .paddingTrailing(10)
    .paddingVertical(5)
    .cornerRadius(8)
    .background(() => (isSelected(anchor()) ? "#7f7f7f3d" : null))
    .hoverBackground(() => (isSelected(anchor()) ? "#7f7f7f3d" : "#7f7f7f1c"))
    .frame({ maxWidth: "infinity" })
    .fixed()
    .block("h:" + groupId)
    .onTap(() => selectWorkspace(anchor()?.id))
    .onDoubleTap(() => setEditingId("h:" + groupId))
    .contextMenu([
      Button("Rename Group", () => setEditingId("h:" + groupId)),
      Button(() => (isCollapsed(g()) ? "Expand" : "Collapse"), () => toggleCollapse(g())),
      Button(() => (g().pinned ? "Unpin Group" : "Pin Group"), () =>
        cmux("workspace.group.action", { group_id: groupId, action: g().pinned ? "unpin" : "pin" })),
      Divider(),
      Button("Ungroup", groupAct("ungroup")),
      Button("Delete Group", groupAct("delete")).destructive(),
    ]);
}

// Identical geometry to groupHeader (chevron box, paddings, semibold 12)
// so entering/leaving rename changes nothing but the text becoming editable.
function groupEditRow(groupId) {
  const g = () => groupById(groupId);
  return HStack({ spacing: 6 }, [
    Image("chevron.right")
      .font(10).weight("semibold").color("tertiary")
      .rotation(() => (isCollapsed(g() ?? {}) ? 0 : 90))
      .frame({ width: 14, height: 16 }),
    TextField(() => g()?.name ?? "", {
      placeholder: "Group name",
      onSubmit: (t) => {
        const name = (t ?? "").trim();
        if (name) cmux("workspace.group.rename", { group_id: groupId, name });
        setEditingId(null);
      },
      onCancel: () => setEditingId(null),
    }).font(12).weight("semibold"),
  ])
    .paddingLeading(8)
    .paddingTrailing(10)
    .paddingVertical(5)
    .cornerRadius(8)
    .background("#7f7f7f3d")
    .frame({ maxWidth: "infinity" })
    .fixed();
}

// --- root ------------------------------------------------------------------------
sidebar(() =>
  VStack({ spacing: 4 }, [
  Reorderable(
    {
      items: flatEntries,
      key: (e) => e.id,
      spacing: 2,
      onMove: handleMove,
    },
    (e, key) => {
      const entry = e(); // kind, ids, and editing are stable per key
      if (entry.kind === "header") {
        return entry.editing ? groupEditRow(entry.groupId) : groupHeader(entry.groupId);
      }
      const w = () => (data.workspaces() ?? []).find((x) => x.id === entry.wsId);
      return entry.editing ? workspaceEditRow(w, e) : workspaceRow(w, e);
    }
  ),
  ]),
  { surface: "glass" }
)
