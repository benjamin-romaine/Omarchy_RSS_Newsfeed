function parsePayload(raw) {
  try {
    var data = JSON.parse(raw || "{}")
    return Array.isArray(data.headlines) ? data.headlines : []
  } catch (e) {
    return []
  }
}

function parseByCategory(raw) {
  try {
    var data = JSON.parse(raw || "{}")
    return (data.byCategory && typeof data.byCategory === "object") ? data.byCategory : {}
  } catch (e) {
    return {}
  }
}

function categoryColor(category) {
  switch (category) {
    case "sports": return "#e07a3f"
    case "world": return "#3f8fe0"
    case "us": return "#3fb0a0"
    case "cyber": return "#d3495a"
    case "tech": return "#8f5fd6"
    default: return "#888888"
  }
}

function relativeTime(iso) {
  if (!iso) return ""
  var then = Date.parse(iso)
  if (isNaN(then)) return ""
  var diffSec = Math.max(0, (Date.now() - then) / 1000)

  if (diffSec < 60) return "just now"
  var mins = Math.floor(diffSec / 60)
  if (mins < 60) return mins + "m ago"
  var hours = Math.floor(mins / 60)
  if (hours < 24) return hours + "h ago"
  var days = Math.floor(hours / 24)
  if (days < 7) return days + "d ago"
  return Math.floor(days / 7) + "w ago"
}

if (typeof module !== "undefined") {
  module.exports = {
    parsePayload: parsePayload,
    parseByCategory: parseByCategory,
    categoryColor: categoryColor,
    relativeTime: relativeTime
  }
}
