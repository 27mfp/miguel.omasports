.pragma library
.import "core.js" as Core

// Provider URL validation and safe external-link resolution.

function cleanPageUrl(raw) {
  var url = String(raw || "").trim()
  if (!url) return ""
  if (/^https:\/\//i.test(url)) return url
  // Keep non-HTTPS absolute URLs out of the parsed value. They are not
  // useful for provider detail pages and must never reach curl/xdg-open.
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(url)) return ""
  if (url.charAt(0) === "/" && url.charAt(1) !== "/") return url
  return "/" + url.replace(/^\/+/, "")
}

function trustedHost(host, allowedHosts) {
  var value = String(host || "").toLowerCase().replace(/\.$/, "")
  var hosts = Core.arrayFrom(allowedHosts)
  for (var i = 0; i < hosts.length; i++) {
    var allowed = String(hosts[i] || "").toLowerCase().replace(/\.$/, "")
    if (value === allowed || value.slice(-(allowed.length + 1)) === "." + allowed) return true
  }
  return false
}

function trustedHttpsUrl(raw, allowedHosts) {
  var url = String(raw || "").trim()
  // Reject credentials, ports, non-HTTPS schemes, control characters, and
  // malformed hostnames before handing a provider URL to a local process.
  if (!/^https:\/\/[^\s/?#]+(?:[/?#]|$)/i.test(url) || /[\u0000-\u001f\u007f]/.test(url)) return ""
  var match = url.match(/^https:\/\/([^\s/@?#]+)(?:[/?#].*)?$/i)
  if (!match || !trustedHost(match[1], allowedHosts)) return ""
  return url
}

function isTrustedCrestUrl(raw, sport) {
  var s = String(sport || "football").toLowerCase()
  var hosts = s === "football" ? ["fotmob.com"] : ["espncdn.com", "espn.com"]
  return trustedHttpsUrl(raw, hosts) !== ""
}

function matchExternalUrl(match) {
  if (!match) return ""
  var sport = String(match.sport || "football").toLowerCase()
  var raw = String(match.pageUrl || "").trim()
  var base = "https://www.espn.com/" + sport
  var hosts = ["espn.com"]
  if (sport === "football") {
    base = "https://www.fotmob.com"
    hosts = ["fotmob.com"]
  } else if (sport === "f1") {
    base = "https://www.formula1.com"
    hosts = ["formula1.com", "wikipedia.org"]
  }
  // Relative paths are common in FotMob and ESPN payloads; resolve them
  // against the sport's known base so a click opens the actual article, not
  // a useless bare-host root. F1 has no fixed base — only fully-qualified
  // Wikipedia or formula1.com links reach this branch.
  if (raw.charAt(0) === "/" && raw.charAt(1) !== "/") {
    if (sport === "football" || sport === "nba" || sport === "nfl" || sport === "mlb" || sport === "nhl") {
      return base + raw
    }
  }
  return trustedHttpsUrl(raw, hosts) || base
}

function matchDetailUrl(match) {
  if (!match || String(match.sport || "football").toLowerCase() !== "football") return ""
  var raw = String(match.pageUrl || "").trim()
  if (raw.charAt(0) === "/" && raw.charAt(1) !== "/") return "https://www.fotmob.com" + raw
  return trustedHttpsUrl(raw, ["fotmob.com"])
}
