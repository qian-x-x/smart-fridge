"""Package the current working tree as source only, without committing or building.

Usage: python scripts/Package-Source.py [--dry-run] [--archive-name NAME.zip]
The existing Package-Delivery.py keeps its clean-commit/full-delivery behavior.
"""

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRS = {"apps", "backend", "contracts", "infra", "scripts", "docs", ".github"}
ROOT_FILES = {"README.md", "AGENTS.md", ".editorconfig", ".gitattributes", ".gitignore"}
EXCLUDED_DIRS = {
    ".git", ".workbuddy", ".codex", "output", "交付包", "node_modules", "build", "dist",
    "target", ".dart_tool", ".gradle", ".kotlin", ".pub-cache", ".pub", ".cache", ".vite",
    ".turbo", ".pnpm-store", "__pycache__", "coverage", "logs", "tmp", "temp", ".idea", ".vscode",
    "test-results", "playwright-report", "allure-results", "surefire-reports", "failsafe-reports",
    "Pods", ".symlinks", "ephemeral", "mysql-data", "redis-data", "minio-data", "rocketmq-data",
    "seata-data", "skywalking-data",
}
EXCLUDED_SUFFIXES = {
    ".apk", ".aab", ".ipa", ".class", ".jar", ".zip", ".7z", ".rar", ".tar", ".gz", ".bz2",
    ".xz", ".log", ".pyc", ".pyo", ".tmp", ".swp", ".iml", ".pem", ".key", ".p12", ".pfx",
    ".jks", ".keystore", ".sqlite", ".sqlite3", ".db", ".kdbx",
}
EXCLUDED_FILES = {
    ".DS_Store", "Thumbs.db", "Desktop.ini", "local.properties", "key.properties", ".packages",
    ".flutter-plugins", ".flutter-plugins-dependencies", ".npmrc", ".pypirc", ".netrc", "id_rsa",
    "id_ed25519", "credentials.json",
}
WRAPPER = "apps/fridge-app/android/gradle/wrapper/gradle-wrapper.jar"
LOCAL_ROUTE = "backend/gateway-service/src/main/resources/application-local.yml"
GUIDE = "docs/交付/源码解压与使用说明.md"
PREFIX = "xiaoyi-fridge/"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def exclusion(name):
    path = PurePosixPath(name)
    parts, leaf = path.parts, path.name
    if path.is_absolute() or ".." in parts or "\\" in name or ":" in name:
        raise ValueError(f"Unsafe source path: {name}")
    if any(part in EXCLUDED_DIRS for part in parts):
        return "dependency, cache, output or local workspace directory"
    if name.startswith("apps/admin-web/"):
        return "removed administrative prototype"
    if name.startswith("infra/skywalking/agent/") or name.startswith("infra/skywalking/agent-"):
        return "external SkyWalking Agent runtime"
    if len(parts) == 1:
        if leaf not in ROOT_FILES and path.suffix.lower() not in {".docx", ".xlsx"}:
            return "outside the declared root-file scope"
    elif parts[0] not in SOURCE_DIRS:
        return "outside the declared source-directory scope"
    if leaf in EXCLUDED_FILES or leaf.startswith("~$") or leaf.endswith("~"):
        return "machine configuration, credential file or editor temporary"
    if leaf == ".env" or (leaf.startswith(".env.") and leaf != ".env.example"):
        return "machine-specific environment"
    if (leaf.startswith("application-local.") and name != LOCAL_ROUTE) or leaf.startswith("application-secret."):
        return "machine-specific service configuration"
    if path.suffix.lower() in EXCLUDED_SUFFIXES and name != WRAPPER:
        return "compiled binary, nested archive, log, credential or database"
    return None


def sources():
    names = sorted({p.decode("utf-8") for p in git("ls-files", "--cached", "--others", "--exclude-standard", "-z").split(b"\0") if p})
    result, excluded = [], []
    for name in names:
        reason = exclusion(name)
        if reason:
            excluded.append({"path": name, "reason": reason})
            continue
        path = ROOT / name
        if not path.exists():
            excluded.append({"path": name, "reason": "deleted from the current working tree"})
            continue
        info = path.lstat()
        if path.is_symlink() or getattr(info, "st_file_attributes", 0) & 0x400 or not stat.S_ISREG(info.st_mode):
            raise ValueError(f"Refusing a linked or non-regular source: {name}")
        if not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"Source resolves outside workspace: {name}")
        result.append(name)
    return result, excluded


def zip_entry(name, data, executable=False):
    entry = zipfile.ZipInfo(PREFIX + name, datetime.now().timetuple()[:6])
    entry.create_system = 3
    entry.external_attr = (stat.S_IFREG | (0o755 if executable else 0o644)) << 16
    entry.compress_type = zipfile.ZIP_DEFLATED
    return entry, data


def write_new(path, data):
    with path.open("xb") as stream:
        stream.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--archive-name", default=f"小易冰箱-源码-{datetime.now():%Y%m%d}.zip")
    args = parser.parse_args()
    if not args.archive_name.endswith(".zip") or re.search(r'[\\/:*?"<>|]', args.archive_name) or args.archive_name.startswith("."):
        raise ValueError("Archive name must be a plain .zip filename")
    names, excluded = sources()
    required = {"README.md", "apps/fridge-app/pubspec.lock", "apps/frontend-demo/index.html", "backend/pom.xml", "contracts/openapi/smart-fridge-v1.yaml", WRAPPER, LOCAL_ROUTE, GUIDE}
    if not required.issubset(names):
        raise ValueError(f"Missing required source files: {sorted(required - set(names))}")
    summary = {
        "sourceFileCount": len(names), "sourceBytes": sum((ROOT / n).stat().st_size for n in names),
        "directories": dict(sorted(Counter(PurePosixPath(n).parts[0] for n in names).items())),
        "excludedCandidateCount": len(excluded), "archiveName": args.archive_name,
    }
    if args.dry_run:
        print(json.dumps(summary, ensure_ascii=True, indent=2))
        return

    output = ROOT / "交付包"
    output.mkdir(exist_ok=True)
    if output.is_symlink() or getattr(output.lstat(), "st_file_attributes", 0) & 0x400 or output.resolve() != ROOT / "交付包":
        raise ValueError("Output directory must be the real local 交付包 directory")
    archive_path = output / args.archive_name
    stem = archive_path.stem
    guide_path = output / f"{stem}-解压与使用说明.md"
    manifest_path = output / f"{stem}-文件清单.json"
    checksum_path = output / f"{args.archive_name}.sha256"
    for path in [archive_path, guide_path, manifest_path, checksum_path]:
        if path.exists():
            raise FileExistsError(f"Refusing to overwrite: {path.name}")

    revision = git("rev-parse", "HEAD").decode().strip()
    status_before = git("status", "--porcelain=v1", "-z", "--untracked-files=all")
    executable = set()
    for line in git("ls-files", "--stage", "-z").split(b"\0"):
        if line:
            meta, name = line.split(b"\t", 1)
            if meta.startswith(b"100755 "):
                executable.add(name.decode("utf-8"))
    manifest = {
        "project": "小易冰箱", "kind": "current-working-tree-source-only", "packagedAt": datetime.now().astimezone().isoformat(),
        "gitBaseCommit": revision, "includesUncommittedChanges": bool(status_before), "verifiedAgainstCommittedRevision": False,
        "format": "ZIP/Deflate with UTF-8 filenames", "archiveRoot": PREFIX,
        "scope": sorted(SOURCE_DIRS), "rootFiles": sorted(ROOT_FILES),
        "rootSupportingDocuments": "existing root-level .docx and .xlsx",
        "retainedRuntimeAssets": ["Three.js web/vendor", "fonts and application images", "Gradle wrapper JAR"],
        "installedDependenciesBuildsCachesDatabasesIncluded": False,
        "ignoredFilesIncluded": False, "businessAcceptanceRerun": False,
        "excludedCandidates": excluded, "files": [],
    }
    source_payloads = {}
    with zipfile.ZipFile(archive_path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in names:
            data = (ROOT / name).read_bytes()
            if re.search(rb"(?m)^-----BEGIN (?:(?:RSA|EC|OPENSSH|DSA) )?PRIVATE KEY-----\s*$", data):
                raise ValueError(f"Private key material in source: {name}")
            entry, data = zip_entry(name, data, name in executable)
            archive.writestr(entry, data, compresslevel=6)
            record = {"path": name, "bytes": len(data), "sha256": digest(data), "executable": name in executable}
            manifest["files"].append(record)
            source_payloads[name] = record["sha256"]
        guide = (ROOT / GUIDE).read_bytes()
        archive.writestr(*zip_entry("解压与使用说明.md", guide), compresslevel=6)
        manifest["files"].append({"path": "解压与使用说明.md", "bytes": len(guide), "sha256": digest(guide), "generatedCopyOf": GUIDE})
        manifest["sourceFileCount"] = len(names)
        manifest["payloadFileCount"] = len(manifest["files"])
        manifest_data = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        archive.writestr(*zip_entry("source-manifest.json", manifest_data), compresslevel=6)

    expected = {PREFIX + item["path"]: item for item in manifest["files"]}
    seen = set()
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC verification failed")
        for entry in archive.infolist():
            if entry.filename in seen or not entry.filename.startswith(PREFIX) or ".." in PurePosixPath(entry.filename).parts:
                raise ValueError("Duplicate or unsafe ZIP member")
            seen.add(entry.filename)
            if entry.filename == PREFIX + "source-manifest.json":
                if archive.read(entry) != manifest_data:
                    raise ValueError("Manifest bytes differ")
                continue
            item = expected.get(entry.filename)
            if item is None or digest(archive.read(entry)) != item["sha256"]:
                raise ValueError(f"Unexpected or changed ZIP payload: {entry.filename}")
        if seen != set(expected) | {PREFIX + "source-manifest.json"}:
            raise ValueError("Archive inventory differs from manifest")
    if sources()[0] != names or git("rev-parse", "HEAD").decode().strip() != revision or git("status", "--porcelain=v1", "-z", "--untracked-files=all") != status_before:
        raise ValueError("Source inventory or Git state changed during packaging")
    for name, sha in source_payloads.items():
        if digest((ROOT / name).read_bytes()) != sha:
            raise ValueError(f"Workspace source changed during packaging: {name}")
    write_new(guide_path, guide)
    write_new(manifest_path, manifest_data)
    sha = digest(archive_path.read_bytes())
    write_new(checksum_path, f"{sha}  {archive_path.name}\n".encode("utf-8"))
    print(json.dumps({**summary, "archive": str(archive_path), "archiveBytes": archive_path.stat().st_size, "sha256": sha, "zipEntriesVerified": len(seen), "guide": str(guide_path), "manifest": str(manifest_path)}, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
