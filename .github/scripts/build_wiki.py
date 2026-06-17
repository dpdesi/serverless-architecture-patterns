#!/usr/bin/env python3
"""Generate the GitHub wiki from the in-repo documentation.

Reads docs/patterns/*.md and docs/building-a-subsystem.md and rewrites their
links for the wiki, which is a separate repository:

  - links between docs become wiki page links (event-hub.md -> Event-Hub);
  - links to code (modules, schema, examples, the diagram) become absolute
    repository URLs on the chosen branch;
  - images are copied into the wiki's images/ folder and referenced locally,
    so they render without access to the (private) source repository.

The docs/patterns index becomes the wiki Home page. A _Sidebar is generated.

Usage:  python .github/scripts/build_wiki.py <output-dir>

Environment:
  REPO_ROOT          repository root to read docs from (default: ".")
  REPO_URL           base repo URL for code links
                     (default: https://github.com/dpdesi/serverless-architecture-patterns)
  WIKI_LINK_BRANCH   branch that code links point at (default: "main")
"""
import os
import re
import sys
import posixpath
import shutil

REPO_ROOT = os.environ.get("REPO_ROOT", ".")
OUT = sys.argv[1] if len(sys.argv) > 1 else "wiki-build"
REPO_URL = os.environ.get(
    "REPO_URL", "https://github.com/dpdesi/serverless-architecture-patterns"
)
BRANCH = os.environ.get("WIKI_LINK_BRANCH", "main")

DOC_TO_PAGE = {
    "README.md": "Home",
    "primitives.md": "Primitives",
    "event-hub.md": "Event-Hub",
    "bff-service.md": "BFF-Service",
    "control-service.md": "Control-Service",
    "esg-service.md": "ESG-Service",
    "event-lake.md": "Event-Lake",
    "observability-baseline.md": "Observability-Baseline",
    "fault-monitor.md": "Fault-Monitor",
    "regional-health-check.md": "Regional-Health-Check",
    "frontend-edge.md": "Frontend-Edge",
    "micro-frontend.md": "Micro-Frontend",
    "building-a-subsystem.md": "Building-a-Subsystem",
}

# source path (repo-relative) -> (source dir, output wiki filename)
SOURCES = {
    "docs/patterns/README.md": ("docs/patterns", "Home.md"),
    "docs/patterns/primitives.md": ("docs/patterns", "Primitives.md"),
    "docs/patterns/event-hub.md": ("docs/patterns", "Event-Hub.md"),
    "docs/patterns/bff-service.md": ("docs/patterns", "BFF-Service.md"),
    "docs/patterns/control-service.md": ("docs/patterns", "Control-Service.md"),
    "docs/patterns/esg-service.md": ("docs/patterns", "ESG-Service.md"),
    "docs/patterns/event-lake.md": ("docs/patterns", "Event-Lake.md"),
    "docs/patterns/observability-baseline.md": ("docs/patterns", "Observability-Baseline.md"),
    "docs/patterns/fault-monitor.md": ("docs/patterns", "Fault-Monitor.md"),
    "docs/patterns/regional-health-check.md": ("docs/patterns", "Regional-Health-Check.md"),
    "docs/patterns/frontend-edge.md": ("docs/patterns", "Frontend-Edge.md"),
    "docs/patterns/micro-frontend.md": ("docs/patterns", "Micro-Frontend.md"),
    "docs/building-a-subsystem.md": ("docs", "Building-a-Subsystem.md"),
}

link_rx = re.compile(r"(!?)\[([^\]]*)\]\(([^)]+)\)")


def rewrite_target(target, srcdir):
    target = target.strip()
    if target.startswith(("http://", "https://", "mailto:")) or target.startswith("#"):
        return target
    if "#" in target:
        path, anchor = target.split("#", 1)
        anchor = "#" + anchor
    else:
        path, anchor = target, ""
    base = posixpath.basename(path)
    if path.endswith(".png"):
        return "images/" + base + anchor
    if base in DOC_TO_PAGE:
        return DOC_TO_PAGE[base] + anchor
    repopath = posixpath.normpath(posixpath.join(srcdir, path))
    last = posixpath.basename(repopath)
    kind = "blob" if "." in last else "tree"
    return f"{REPO_URL}/{kind}/{BRANCH}/{repopath}{anchor}"


def transform(text, srcdir):
    return link_rx.sub(
        lambda m: f"{m.group(1)}[{m.group(2)}]({rewrite_target(m.group(3), srcdir)})",
        text,
    )


def main():
    os.makedirs(OUT, exist_ok=True)
    imgdir = os.path.join(OUT, "images")
    os.makedirs(imgdir, exist_ok=True)

    src_imgs = os.path.join(REPO_ROOT, "docs", "architecture", "patterns")
    for f in os.listdir(src_imgs):
        if f.endswith(".png"):
            shutil.copy(os.path.join(src_imgs, f), os.path.join(imgdir, f))
    shutil.copy(
        os.path.join(REPO_ROOT, "docs", "architecture", "online-order-subsystem.png"),
        os.path.join(imgdir, "online-order-subsystem.png"),
    )

    for rel, (srcdir, outname) in SOURCES.items():
        with open(os.path.join(REPO_ROOT, rel), encoding="utf-8") as fh:
            text = fh.read()
        with open(os.path.join(OUT, outname), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(transform(text, srcdir))

    sidebar = """### Serverless Architecture Patterns

**[Home](Home)**

**Patterns**

- [Event hub](Event-Hub)
- [BFF service](BFF-Service)
- [Control service](Control-Service)
- [ESG service](ESG-Service)
- [Event lake](Event-Lake)
- [Observability baseline](Observability-Baseline)
- [Fault monitor](Fault-Monitor)
- [Regional health check](Regional-Health-Check)
- [Frontend edge](Frontend-Edge)
- [Micro-frontend](Micro-Frontend)
- [Primitives](Primitives)

**[Building a subsystem](Building-a-Subsystem)**

[Repository](%s)
""" % REPO_URL
    with open(os.path.join(OUT, "_Sidebar.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(sidebar)

    print(f"wrote {len(SOURCES)} pages + _Sidebar and images to {OUT}")


if __name__ == "__main__":
    main()
