"""The deployed images, for the SBOM workflow (.github/workflows/sbom.yml).

list: prints a JSON list of {"key", "image"}, one per image of the services'
compose.yml (an image used by several containers is scanned once).

merge <directory> <output>: merges the SBOM of each image (<directory>/sbom-<key>/sbom.json)
into one CycloneDX document, the project infrastructure-docker. Each image is a
component the project depends on, and its packages are its dependencies, so
that nanobom shows through which image a vulnerable package came. The
containers using each image are written to the job summary.
"""

import hashlib
import json
import os
import pathlib
import sys
import urllib.parse

import yaml

# Private images: their own repository uploads their SBOM
PRIVATE_IMAGES = ("ghcr.io/minitrainstore/",)
PROJECT = "infrastructure-docker"


def images() -> dict[str, tuple[str, list[str]]]:
    """Each image by package URL (postgres:18.6 and docker.io/postgres:18.6 are one),
    with the reference to scan and the containers (<service>/<container>) that run it."""
    found: dict[str, tuple[str, list[str]]] = {}
    for compose in sorted(pathlib.Path("services").glob("*/compose.yml")):
        # safe_load resolves anchors and merge keys (<<: *server)
        document = yaml.safe_load(compose.read_text()) or {}
        for name, definition in (document.get("services") or {}).items():
            image = (definition or {}).get("image")
            if not image or image.startswith(PRIVATE_IMAGES):
                continue
            if "$" in image:
                sys.exit(f"{compose}: {name} has a variable in its image")
            found.setdefault(package_url(image), (image, []))[1].append(f"{compose.parent.name}/{name}")
    return found


def key(purl: str) -> str:
    """A name for the image's artifact."""
    return hashlib.sha256(purl.encode()).hexdigest()[:16]


def package_url(image: str) -> str:
    """The image's package URL (pkg:docker), without its digest."""
    reference = image.split("@", 1)[0]
    name, tag = reference, ""
    if ":" in reference.rsplit("/", 1)[-1]:
        name, tag = reference.rsplit(":", 1)
    parts = name.split("/")
    registry = "docker.io"
    if len(parts) > 1 and ("." in parts[0] or ":" in parts[0]):
        registry, parts = parts[0], parts[1:]
    if registry == "docker.io" and len(parts) == 1:
        parts = ["library", *parts]
    path = "/".join(urllib.parse.quote(part) for part in parts)
    purl = f"pkg:docker/{path}@{urllib.parse.quote(tag)}" if tag else f"pkg:docker/{path}"
    if registry != "docker.io":
        purl += f"?repository_url={urllib.parse.quote(registry, safe='')}"
    return purl


def merge(directory: pathlib.Path, output: pathlib.Path) -> None:
    components: dict[str, dict] = {}
    dependencies: dict[str, set[str]] = {PROJECT: set()}
    summary = ["| Image | Containers | Packages |", "| --- | --- | --- |"]
    for image_reference, (image, containers) in images().items():
        document = json.loads((directory / f"sbom-{key(image_reference)}" / "sbom.json").read_text())
        components[image_reference] = {
            "type": "container",
            "bom-ref": image_reference,
            "name": image,
            "purl": image_reference,
            "properties": [{"name": "infrastructure:containers", "value": ", ".join(containers)}],
        }
        dependencies[PROJECT].add(image_reference)
        packages = dependencies.setdefault(image_reference, set())
        for component in document.get("components", []):
            purl = component.get("purl")
            if not purl or component.get("type") in ("file", "operating-system"):
                continue
            # Components with the same package URL are one in nanobom
            components.setdefault(
                purl,
                {
                    field: component[field]
                    for field in ("type", "name", "version", "purl", "licenses")
                    if field in component
                }
                | {"bom-ref": purl},
            )
            packages.add(purl)
        summary.append(f"| `{image}` | {', '.join(containers)} | {len(packages)} |")
    merged = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {"component": {"type": "application", "bom-ref": PROJECT, "name": PROJECT}},
        "components": list(components.values()),
        "dependencies": [
            {"ref": ref, "dependsOn": sorted(depends)} for ref, depends in dependencies.items()
        ],
    }
    output.write_text(json.dumps(merged))
    if "GITHUB_STEP_SUMMARY" in os.environ:
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as file:
            file.write("\n".join(["## Images", "", *summary, ""]))


def main() -> None:
    if sys.argv[1:] == ["list"]:
        print(json.dumps([{"key": key(purl), "image": image} for purl, (image, _) in images().items()]))
    elif len(sys.argv) == 4 and sys.argv[1] == "merge":
        merge(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    else:
        sys.exit("usage: sbom-images.py list | merge <directory> <output>")


if __name__ == "__main__":
    main()
