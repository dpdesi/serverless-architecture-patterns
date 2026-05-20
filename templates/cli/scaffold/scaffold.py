#!/usr/bin/env python3
from pathlib import Path
import argparse
import re


def parse_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def render(text: str, values: dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        return values.get(match.group(1), match.group(0))

    return re.sub(r"{{\s*([a-zA-Z0-9_]+)\s*}}", replace, text)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render a serverless subsystem skeleton.")
    parser.add_argument("--values", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    values = parse_values(args.values)
    template_dir = Path(__file__).parent / "templates"
    for source in template_dir.rglob("*.tmpl"):
        relative = source.relative_to(template_dir)
        destination = args.output / relative.with_suffix("")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(render(source.read_text(encoding="utf-8"), values), encoding="utf-8")


if __name__ == "__main__":
    main()
