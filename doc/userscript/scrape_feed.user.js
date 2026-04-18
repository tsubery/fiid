// ==UserScript==
// @name         FIID Scrape Feed
// @namespace    fiid
// @version      1.2
// @description  Sends page HTML to FIID for web scrape feeds
// @run-at       document-start
// @match        https://www.rabobank.com/knowledge/*
// @grant        GM_xmlhttpRequest
// @connect      *
// ==/UserScript==

(function () {
  "use strict";

  var marker = window.name;
  if (marker !== "fiid_scrape") return;

  // Clear immediately so page JS cannot read it
  window.name = "";

  // Restore before navigations (e.g. Cloudflare challenge -> real page)
  var done = false;
  window.addEventListener("beforeunload", function () {
    if (!done) window.name = marker;
  });

  // Hardcode your ingest endpoint here
  var ingestUrl = "https://admin.example.com/admin/reading_list/ingest_html";
  var CHALLENGE_TITLES = ["just a moment", "attention required", "please wait"];

  function isContentReady() {
    var title = (document.title || "").toLowerCase().trim();
    if (!title) return false;
    for (var i = 0; i < CHALLENGE_TITLES.length; i++) {
      if (title.indexOf(CHALLENGE_TITLES[i]) !== -1) return false;
    }
    return true;
  }

  function sendHtml() {
    done = true;
    GM_xmlhttpRequest({
      method: "POST",
      url: ingestUrl,
      headers: { "Content-Type": "application/json" },
      data: JSON.stringify({
        url: location.href,
        html: document.documentElement.outerHTML,
      }),
      onload: function (resp) {
        try {
          var data = JSON.parse(resp.responseText);
          if (data.success) {
            console.log("FIID scrape: " + data.new_items + " new items");
            window.close();
          } else {
            console.error("FIID scrape rejected:", data.error);
          }
        } catch (e) {
          console.error("FIID scrape error:", resp.responseText);
        }
      },
      onerror: function (err) {
        console.error("FIID scrape failed:", err);
      },
    });
  }

  var poll = setInterval(function () {
    if (isContentReady()) {
      clearInterval(poll);
      sendHtml();
    }
  }, 500);

  // Give up after 30 seconds
  setTimeout(function () {
    clearInterval(poll);
  }, 30000);
})();
