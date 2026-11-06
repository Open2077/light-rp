/* The TCG's pictures (cards, sealed products, playmats, rooms, interface art) are served from
   the Open77 CDN, not shipped with the resource: the client no longer downloads ~42 MB of
   images with the server's files, and each picture loads when it is shown (loading="lazy").
   The page is created with the WebUI policy "images" (client/main.lua), which lets it show
   remote HTTPS images and nothing else. Upload: tools/upload-cdn-images.py. A new set of
   pictures goes under a new version folder (v2...), never over v1 (URLs are cached). */
(function () {
  var base = "https://cdn.open77.dev/assets/tcg/v1/";
  window.TCG_CDN = base;
  // "img/cards/x.webp" -> the CDN URL; anything else (an absolute URL) as it is.
  window.tcgAsset = function (path) {
    path = String(path || "");
    return /^img\//.test(path) ? base + path : path;
  };
})();
