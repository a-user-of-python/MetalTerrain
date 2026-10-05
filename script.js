/* MetalTerrain docs: nav toggle, active link, tiny Swift highlighter */
(function () {
  "use strict";

  /* ---- mobile sidebar ---- */
  var toggle = document.getElementById("menu-toggle");
  var sidebar = document.getElementById("sidebar");
  if (toggle && sidebar) {
    toggle.addEventListener("click", function () {
      sidebar.classList.toggle("open");
    });
    sidebar.addEventListener("click", function (e) {
      if (e.target.tagName === "A") sidebar.classList.remove("open");
    });
  }

  /* ---- active nav link ---- */
  try {
    var path = window.location.pathname.split("/").pop() || "index.html";
    var links = document.querySelectorAll(".sidebar a");
    links.forEach(function (a) {
      var href = a.getAttribute("href");
      if (href === path) a.classList.add("active");
    });
  } catch (e) { /* ignore */ }

  /* ---- tiny Swift highlighter ---- */
  var KEYWORDS = ("associatedtype|async|await|break|case|catch|class|continue|default|defer|deinit|do|else|enum|extension|" +
    "fallthrough|fileprivate|final|for|func|guard|if|import|in|init|inout|internal|is|lazy|let|mutating|" +
    "nil|nonmutating|open|operator|optional|override|postfix|prefix|private|protocol|public|repeat|required|" +
    "return|self|Self|static|struct|subscript|super|switch|throw|throws|try|typealias|unowned|var|weak|where|while|" +
    "true|false|some|any|actor|isolated|nonisolated|package").split("|");
  var KW = {};
  KEYWORDS.forEach(function (k) { KW[k] = true; });

  function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  function highlightSwift(src) {
    var out = "", i = 0, n = src.length;
    function span(cls, text) { return '<span class="' + cls + '">' + esc(text) + "</span>"; }

    while (i < n) {
      var c = src[i], two = src.substr(i, 2);

      // line comment
      if (two === "//") {
        var j = src.indexOf("\n", i);
        if (j < 0) j = n;
        out += span("tok-c", src.slice(i, j));
        i = j;
        continue;
      }
      // block comment
      if (two === "/*") {
        var j = src.indexOf("*/", i + 2);
        j = j < 0 ? n : j + 2;
        out += span("tok-c", src.slice(i, j));
        i = j;
        continue;
      }
      // string
      if (c === '"') {
        var j = i + 1, buf = '"';
        while (j < n) {
          if (src[j] === "\\") { buf += src.substr(j, 2); j += 2; continue; }
          buf += src[j];
          if (src[j] === '"') { j++; break; }
          j++;
        }
        out += span("tok-s", buf);
        i = j;
        continue;
      }
      // attribute
      if (c === "@") {
        var m = /^@[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i));
        out += span("tok-f", m[0]);
        i += m[0].length;
        continue;
      }
      // number
      var nm = /^(0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*(\.\d[\d_]*)?([eE][+-]?\d+)?)/.exec(src.slice(i));
      if (nm && (i === 0 || /[^A-Za-z0-9_.]/.test(src[i - 1]))) {
        out += span("tok-n", nm[0]);
        i += nm[0].length;
        continue;
      }
      // identifier / keyword / type
      var id = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(i));
      if (id) {
        var w = id[0];
        if (KW[w]) out += span("tok-k", w);
        else if (/^[A-Z]/.test(w)) out += span("tok-t", w);
        else {
          // function call if followed by (
          var k = i + w.length;
          while (k < n && src[k] === " ") k++;
          if (src[k] === "(" || src[k] === ":") out += span("tok-f", w);
          else out += esc(w);
        }
        i += w.length;
        continue;
      }
      out += esc(c);
      i++;
    }
    return out;
  }

  document.querySelectorAll("pre code.language-swift, pre code.swift").forEach(function (el) {
    el.innerHTML = highlightSwift(el.textContent);
  });
})();
