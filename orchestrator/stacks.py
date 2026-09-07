from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import LandscapeConfig, load_stacks_manifest


class StackGraphError(RuntimeError):
    pass


@dataclass(frozen=True)
class Stack:
    name: str
    relative_path: str
    depends_on: tuple[str, ...]

    def absolute_path(self, account_dir: Path) -> Path:
        return account_dir / self.relative_path


def build_graph(manifest: dict[str, dict[str, Any]] | None = None) -> dict[str, Stack]:
    raw = manifest or load_stacks_manifest()
    stacks: dict[str, Stack] = {}
    for name, meta in raw.items():
        stacks[name] = Stack(
            name=name,
            relative_path=meta["path"],
            depends_on=tuple(meta.get("depends_on") or []),
        )
    for stack in stacks.values():
        for dep in stack.depends_on:
            if dep not in stacks:
                raise StackGraphError(f"stack {stack.name!r} depends on unknown {dep!r}")
    return stacks


def topo_sort(stacks: dict[str, Stack], selected: set[str] | None = None) -> list[Stack]:
    """Return stacks in dependency order. If selected is set, include transitive deps."""
    if selected is None:
        needed = set(stacks)
    else:
        unknown = selected - set(stacks)
        if unknown:
            raise StackGraphError(f"unknown stacks: {sorted(unknown)}")
        needed = set()
        queue = deque(selected)
        while queue:
            name = queue.popleft()
            if name in needed:
                continue
            needed.add(name)
            queue.extend(stacks[name].depends_on)

    indegree = {name: 0 for name in needed}
    children: dict[str, list[str]] = {name: [] for name in needed}
    for name in needed:
        for dep in stacks[name].depends_on:
            if dep not in needed:
                continue
            indegree[name] += 1
            children[dep].append(name)

    ready = deque(sorted(n for n, d in indegree.items() if d == 0))
    ordered: list[Stack] = []
    while ready:
        name = ready.popleft()
        ordered.append(stacks[name])
        for child in sorted(children[name]):
            indegree[child] -= 1
            if indegree[child] == 0:
                ready.append(child)

    if len(ordered) != len(needed):
        raise StackGraphError("cycle detected in stack dependency graph")
    return ordered


def resolve_targets(
    cfg: LandscapeConfig,
    *,
    stack_names: list[str] | None,
    all_stacks: bool,
) -> list[Stack]:
    graph = build_graph()
    if all_stacks and stack_names:
        raise StackGraphError("pass either --all or stack names, not both")
    if all_stacks:
        return topo_sort(graph, None)
    if not stack_names:
        raise StackGraphError("specify one or more stack names, or --all")
    return topo_sort(graph, set(stack_names))
