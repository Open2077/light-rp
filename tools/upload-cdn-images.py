"""Upload a folder of interface pictures to the Open77 CDN (R2 bucket `open77`, served at
https://cdn.open77.dev/) and check every file through its public URL.

The wardrobe icons and the TCG pictures are not shipped with the resources any more: the pages
load them from the CDN (WebUI policy "images", loading="lazy"). Cloudflare writes go through
the cf CLI (operator rule), one object per call, in parallel.

    python tools/upload-cdn-images.py <local folder> <key prefix> [--workers 16] [--verify-only]

    # the wardrobe icons (open77_wardrobe_ui web/icons/<m|f>/*.webp)
    python tools/upload-cdn-images.py build/wardrobe-icons assets/wardrobe/v1/icons
    # the TCG pictures (op77_tcg web/img/**)
    python tools/upload-cdn-images.py build/tcg-img assets/tcg/v1/img

A changed picture set goes under a new version folder (v2...): the URLs are cached, never
overwrite v1 with different bytes. The script refuses to replace an existing object whose
public bytes differ (pass --replace to override on purpose).
"""
import argparse, concurrent.futures, hashlib, os, pathlib, subprocess, sys, time, urllib.request

CDN = "https://cdn.open77.dev/"
BUCKET = "open77"
TYPES = {".webp": "image/webp", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".svg": "image/svg+xml", ".avif": "image/avif"}
CF = ["node", str(pathlib.Path(os.environ.get("APPDATA", "")) / "npm/node_modules/cf/bin/cf")]


def fetch(url):
    request = urllib.request.Request(url, headers={"Cache-Control": "no-cache", "User-Agent": "open77-cdn-upload"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def one(path, key, verify_only, replace):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    # Never probe the bare URL: Cloudflare caches a 404 for hours (max-age 14400) and the page
    # would keep getting it after the upload (2026-11-06). A query string bypasses that entry.
    public = fetch(CDN + key + "?probe=" + str(time.time_ns()))
    if public is not None and hashlib.sha256(public).hexdigest() == digest:
        return "same", key
    if verify_only:
        return "missing" if public is None else "different", key
    if public is not None and not replace:
        return "conflict", key
    for attempt in range(4):
        p = subprocess.run(CF + ["r2", "objects", "put", key, "--bucket-name", BUCKET, "--file", str(path),
                                 "--content-type", TYPES.get(path.suffix.lower(), "application/octet-stream"), "-q"],
                           capture_output=True, timeout=300)
        if p.returncode == 0:
            break
        time.sleep(2 + attempt * 3)
    else:
        return "failed", key + " " + p.stderr.decode(errors="replace")[-300:]
    for attempt in range(5):
        public = fetch(CDN + key + "?v=" + digest[:12])
        if public is not None and hashlib.sha256(public).hexdigest() == digest:
            return "uploaded", key
        time.sleep(1 + attempt)
    return "unverified", key


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("prefix")
    ap.add_argument("--workers", type=int, default=16)
    ap.add_argument("--verify-only", action="store_true")
    ap.add_argument("--replace", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.folder)
    prefix = a.prefix.strip("/")
    files = sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in TYPES)
    if not files:
        sys.exit("no picture under " + str(root))
    counts, problems = {}, []
    with concurrent.futures.ThreadPoolExecutor(a.workers) as pool:
        jobs = [pool.submit(one, p, prefix + "/" + p.relative_to(root).as_posix(), a.verify_only, a.replace) for p in files]
        for i, job in enumerate(concurrent.futures.as_completed(jobs), 1):
            state, detail = job.result()
            counts[state] = counts.get(state, 0) + 1
            if state not in ("same", "uploaded"):
                problems.append(state + " " + detail)
            if i % 200 == 0 or i == len(jobs):
                print(f"{i}/{len(jobs)} {counts}", flush=True)
    for line in problems[:40]:
        print(line)
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
