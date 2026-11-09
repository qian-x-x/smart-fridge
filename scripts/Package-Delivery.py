"""Package a clean, committed revision and existing verified build artifacts.

Usage: python scripts/Package-Delivery.py [--output-dir PATH]
No commit, push, runtime restart, deletion, or dependency installation is performed.
"""

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import zipfile
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/reviews/evidence/2026-11-09-real-business"
HISTORICAL_ZIP = "docs/提交材料/小易冰箱-项目源码.zip"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def verify_source(path, revision):
    tree = {}
    for entry in git("ls-tree", "-r", "-z", revision).split(b"\0"):
        if entry:
            meta, name = entry.split(b"\t", 1)
            mode, kind, object_id = meta.split()
            if kind != b"blob" or mode not in (b"100644", b"100755"):
                raise ValueError("Unsupported Git entry in delivery")
            tree[name.decode("utf-8")] = object_id.decode("ascii")
    expected = set(tree) - {HISTORICAL_ZIP}
    seen = set()
    # git archive honors .gitattributes eol=crlf for PowerShell/batch files.
    # Verify their canonical Git bytes after that declared text conversion only.
    attributes = subprocess.check_output(
        ["git", "check-attr", "-z", "--stdin", "eol"], cwd=ROOT,
        input=b"\0".join(name.encode("utf-8") for name in tree) + b"\0",
    ).split(b"\0")
    crlf_paths = {attributes[i].decode("utf-8") for i in range(0, len(attributes) - 1, 3)
                  if attributes[i + 2] == b"crlf"}
    normalized = []
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP CRC failure")
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            name = entry.filename.removeprefix("xiaoyi-fridge/")
            parts = PurePosixPath(name).parts
            if not entry.filename.startswith("xiaoyi-fridge/") or ".." in parts:
                raise ValueError("Unexpected source ZIP path")
            if name in seen or name not in expected:
                raise ValueError(f"Unexpected or duplicate source: {name}")
            data = archive.read(entry)
            header = f"blob {len(data)}\0".encode("ascii")
            if hashlib.sha1(header + data).hexdigest() != tree[name]:
                canonical = data.replace(b"\r\n", b"\n") if name in crlf_paths else data
                canonical_header = f"blob {len(canonical)}\0".encode("ascii")
                if hashlib.sha1(canonical_header + canonical).hexdigest() != tree[name]:
                    raise ValueError(f"Source differs from committed Git blob: {name}")
                normalized.append(name)
            if any(part in {".git", "node_modules", ".dart_tool", "target", ".gradle"} for part in parts):
                raise ValueError(f"Local cache in archive: {name}")
            leaf = parts[-1]
            if leaf == ".env" or (leaf.startswith(".env.") and leaf != ".env.example"):
                raise ValueError(f"Local environment in archive: {name}")
            if leaf.endswith((".pem", ".key", ".jks", ".p12")):
                raise ValueError(f"Private signing material in archive: {name}")
            seen.add(name)
    if seen != expected:
        raise ValueError(f"Source archive misses {len(expected - seen)} files")
    return len(seen), sorted(normalized)


def zip_web(path):
    web = ROOT / "apps/fridge-app/build/web"
    if not (web / "index.html").is_file() or not (web / "flutter_bootstrap.js").is_file():
        raise ValueError("Build Flutter Web before packaging")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for item in sorted(web.rglob("*")):
            if item.is_symlink():
                raise ValueError("Symlink in Web build")
            if item.is_file():
                archive.write(item, item.relative_to(web).as_posix())
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("Web ZIP CRC failure")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "交付包")
    args = parser.parse_args()
    if git("status", "--porcelain=v1", "--untracked-files=normal").strip():
        raise ValueError("Commit the intended changes and start from a clean worktree")
    revision = git("rev-parse", "HEAD").decode().strip()
    short = revision[:8]
    now = datetime.now(ZoneInfo("Asia/Shanghai"))
    label = f"小易冰箱-交付-{now:%Y%m%d}-{short}"
    output = args.output_dir.resolve()
    # Never write under tracked source locations. A new directory avoids overwrites.
    if output.is_relative_to(ROOT) and output != ROOT / "交付包":
        raise ValueError("Inside the workspace use only the ignored 交付包 output directory")
    package = output / label
    package.mkdir(parents=True, exist_ok=False)
    source_dir, documents, artifacts = (package / name for name in ("source", "documents", "artifacts"))
    for folder in (source_dir, documents, artifacts):
        folder.mkdir()
    source_zip = source_dir / f"小易冰箱-源码-{short}.zip"
    subprocess.run(["git", "archive", "--format=zip", "--prefix=xiaoyi-fridge/", "-o", str(source_zip), revision], cwd=ROOT, check=True)
    file_count, normalized_eol_files = verify_source(source_zip, revision)
    for name in ("小易冰箱技术介绍.docx", "小易冰箱技术介绍.md", "交付与运行说明.md"):
        shutil.copy2(ROOT / "docs/交付" / name, documents / name)
    zip_web(artifacts / "小易冰箱-Web.zip")
    apk = ROOT / "apps/fridge-app/build/app/outputs/flutter-apk/app-release.apk"
    android = json.loads((EVIDENCE / "android-build.json").read_text(encoding="utf-8-sig"))
    if digest(apk).upper() != android["sha256"].upper():
        raise ValueError("APK hash differs from the accepted build record")
    shutil.copy2(apk, artifacts / "小易冰箱-Android-测试版.apk")
    (package / "请先阅读.txt").write_text(
        "先阅读 documents/交付与运行说明.md，再阅读技术介绍Word文档。\n"
        "source是已提交源码；artifacts是已有构建产物，仍需运行后端。\n"
        "Android测试包固定API地址192.168.10.225:8080，换电脑需重新构建；未真机验收。\n"
        f"Git提交：{revision}\n", encoding="utf-8")
    files = []
    for item in sorted(package.rglob("*")):
        if item.is_file():
            files.append({"path": item.relative_to(package).as_posix(), "bytes": item.stat().st_size, "sha256": digest(item)})
    manifest = {
        "project": "小易冰箱", "packagedAt": now.isoformat(), "gitCommit": revision,
        "sourceFileCount": file_count, "sourceVerifiedAgainstGitBlobs": True,
        "gitDeclaredCrlfNormalization": normalized_eol_files,
        "sourceExcluded": [HISTORICAL_ZIP], "dependenciesAndDockerImagesIncluded": False,
        "acceptanceRecord": "docs/reviews/evidence/2026-11-09-real-business/summary.json",
        "acceptanceDate": "2026-11-09", "backendTests": 86, "flutterTests": 92,
        "actualApiAssertions": 223, "actualWebAssertions": 10,
        "acceptanceRerunDuringPackaging": False,
        "android": android,
        "pending": ["Android真机验收", "正式签名", "持续容量压测", "接收电脑重新验收"],
        "files": files,
    }
    manifest_path = package / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sums = [f"{digest(item)}  {item.relative_to(package).as_posix()}" for item in sorted(package.rglob("*")) if item.is_file()]
    (package / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")
    bundle = output / f"{label}.zip"
    # ZIP creation never overwrites an existing delivery.
    with zipfile.ZipFile(bundle, "x", zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        for item in sorted(package.rglob("*")):
            if item.is_file():
                archive.write(item, item.relative_to(output).as_posix())
    with zipfile.ZipFile(bundle) as archive:
        if archive.testzip() is not None:
            raise ValueError("Delivery ZIP CRC failure")
    bundle.with_suffix(".zip.sha256").write_text(f"{digest(bundle)}  {bundle.name}\n", encoding="utf-8")
    print(json.dumps({"bundle": str(bundle), "bytes": bundle.stat().st_size, "sha256": digest(bundle), "gitCommit": revision, "sourceFilesVerified": file_count}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
