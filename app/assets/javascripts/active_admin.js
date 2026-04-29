//= require active_admin/base

document.addEventListener("DOMContentLoaded", function () {
  const app = document.getElementById("reading-list-app");
  if (!app) return;

  const PENDING_ARCHIVES_KEY = "readingList.pendingArchives";
  const ARTICLES_CACHE_KEY = "readingList.articlesCache";
  const COOKIE_PER_PAGE = "readingList.perPage";
  const COOKIE_DAYS = "readingList.days";

  function getCookie(name) {
    const match = document.cookie.match(new RegExp("(^|; )" + name + "=([^;]*)"));
    return match ? decodeURIComponent(match[2]) : null;
  }

  function setCookie(name, value) {
    if (value === null || value === "") {
      document.cookie = name + "=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; SameSite=Lax";
    } else {
      const expires = new Date(Date.now() + 365 * 86400000).toUTCString();
      document.cookie = name + "=" + encodeURIComponent(value) + "; expires=" + expires + "; path=/; SameSite=Lax";
    }
  }

  const ReadingListController = {
    articles: [],
    currentIndex: 0,
    currentPage: 1,
    hasMore: false,
    total: 0,
    loading: false,
    _renderRequestId: 0,
    days: null,
    perPage: null,
    syncing: false,
    sidebarCollapsed: false,
    archiveSyncTimeout: null,

    init: function () {
      const urlParams = new URLSearchParams(window.location.search);
      this.days = urlParams.get("days") || getCookie(COOKIE_DAYS) || null;
      this.perPage = urlParams.get("per_page") || getCookie(COOKIE_PER_PAGE) || null;
      this.bindEvents();
      this.syncPendingArchives();
      this.fetchArticles(1);
    },

    openScrapeFeeds: function (urls) {
      urls.forEach(function (url) {
        window.open(url, "_blank", "noreferrer");
      });
    },

    showToast: function (message) {
      const toast = document.createElement("div");
      toast.textContent = message;
      Object.assign(toast.style, {
        position: "fixed",
        bottom: "1.5rem",
        right: "1.5rem",
        background: "#333",
        color: "#fff",
        padding: "0.75rem 1.25rem",
        borderRadius: "0.5rem",
        fontSize: "0.875rem",
        boxShadow: "0 4px 12px rgba(0,0,0,0.25)",
        zIndex: "9999",
        opacity: "0",
        transition: "opacity 0.3s ease",
      });
      document.body.appendChild(toast);
      requestAnimationFrame(() => (toast.style.opacity = "1"));
      setTimeout(() => {
        toast.style.opacity = "0";
        toast.addEventListener("transitionend", () => toast.remove());
      }, 3000);
    },

    showUndoToast: function (message, onUndo) {
      const existing = document.getElementById("undo-toast");
      if (existing) existing.remove();

      const toast = document.createElement("div");
      toast.id = "undo-toast";
      Object.assign(toast.style, {
        position: "fixed",
        bottom: "1.5rem",
        right: "1.5rem",
        background: "#333",
        color: "#fff",
        padding: "0.75rem 1.25rem",
        borderRadius: "0.5rem",
        fontSize: "0.875rem",
        boxShadow: "0 4px 12px rgba(0,0,0,0.25)",
        zIndex: "9999",
        opacity: "0",
        transition: "opacity 0.3s ease",
        display: "flex",
        alignItems: "center",
        gap: "1rem",
      });

      const text = document.createElement("span");
      text.textContent = message;

      const btn = document.createElement("button");
      btn.textContent = "Undo";
      Object.assign(btn.style, {
        background: "transparent",
        border: "1px solid #fff",
        color: "#fff",
        borderRadius: "0.25rem",
        padding: "0.2rem 0.6rem",
        cursor: "pointer",
        fontSize: "0.8rem",
      });
      btn.addEventListener("click", () => {
        toast.remove();
        onUndo();
      });

      toast.appendChild(text);
      toast.appendChild(btn);
      document.body.appendChild(toast);
      requestAnimationFrame(() => (toast.style.opacity = "1"));
      setTimeout(() => {
        toast.style.opacity = "0";
        toast.addEventListener("transitionend", () => toast.remove());
      }, 4000);
    },

    undoArchive: function (article, articleIndex, savedCurrentIndex) {
      if (this.archiveSyncTimeout) {
        clearTimeout(this.archiveSyncTimeout);
        this.archiveSyncTimeout = null;
      }
      this.removePendingArchive(article.id);
      const insertAt = Math.min(articleIndex, this.articles.length);
      this.articles.splice(insertAt, 0, article);
      this.total++;
      this.currentIndex = Math.min(savedCurrentIndex, this.articles.length - 1);
      this.renderSidebar();
      this.renderArticle(this.currentIndex);
    },

    getPendingArchives: function () {
      try {
        return JSON.parse(localStorage.getItem(PENDING_ARCHIVES_KEY)) || [];
      } catch (e) {
        return [];
      }
    },

    savePendingArchives: function (ids) {
      localStorage.setItem(PENDING_ARCHIVES_KEY, JSON.stringify(ids));
    },

    addPendingArchive: function (id) {
      const pending = this.getPendingArchives();
      if (!pending.includes(id)) {
        pending.push(id);
        this.savePendingArchives(pending);
      }
    },

    removePendingArchive: function (id) {
      const pending = this.getPendingArchives().filter((i) => i !== id);
      this.savePendingArchives(pending);
    },

    getCachedArticles: function () {
      try {
        return JSON.parse(localStorage.getItem(ARTICLES_CACHE_KEY)) || null;
      } catch (e) {
        return null;
      }
    },

    cacheArticles: function (data) {
      try {
        const maxCacheSize = this.perPage ? parseInt(this.perPage) : 100;
        const toCache = {
          ...data,
          items: data.items.slice(0, maxCacheSize),
        };
        localStorage.setItem(ARTICLES_CACHE_KEY, JSON.stringify(toCache));
      } catch (e) {
        // localStorage full or unavailable
      }
    },

    removeFromCache: function (articleId) {
      try {
        const cached = this.getCachedArticles();
        if (cached && cached.items) {
          cached.items = cached.items.filter((item) => item.id !== articleId);
          cached.total = Math.max(0, cached.total - 1);
          this.cacheArticles(cached);
        }
      } catch (e) {
        // ignore
      }
    },

    syncPendingArchives: function () {
      if (this.syncing) return;

      const pending = this.getPendingArchives();
      if (pending.length === 0) return;

      this.syncing = true;
      const id = pending[0];

      const csrfToken = document.querySelector(
        'meta[name="csrf-token"]',
      )?.content;
      fetch("/admin/reading_list/archive?id=" + id, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken },
      })
        .then((response) => response.json())
        .then((data) => {
          this.syncing = false;
          if (data.success) {
            this.removePendingArchive(id);
            this.syncPendingArchives();
          }
        })
        .catch((error) => {
          this.syncing = false;
          console.log("Offline or error, will retry later:", error);
        });
    },

    bindEvents: function () {
      const self = this;

      app.addEventListener("click", function (e) {
        const button = e.target.closest("button");
        if (button) {
          if (button.id === "sidebar-toggle") {
            self.toggleSidebar();
          } else if (button.id === "add-url-btn") {
            self.addUrlFromClipboard();
          } else if (button.id === "prev-btn") {
            self.prev();
          } else if (button.id === "next-btn") {
            self.next();
          } else if (button.id === "archive-btn") {
            self.archive();
          } else if (button.id === "settings-btn") {
            self.toggleSettings();
          }
          return;
        }

        const archiveIcon = e.target.closest(".sidebar-archive");
        if (archiveIcon) {
          const index = parseInt(archiveIcon.dataset.index);
          if (!isNaN(index)) {
            self.archiveAtIndex(index);
          }
          return;
        }

        const sidebarItem = e.target.closest(".sidebar-item");
        if (sidebarItem) {
          const index = parseInt(sidebarItem.dataset.index);
          if (!isNaN(index)) {
            self.currentIndex = index;
            self.renderArticle(index);
            self.renderSidebar();
          }
        }
      });

      document.addEventListener("keydown", (e) => {
        if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA")
          return;

        switch (e.key) {
          case "j":
          case "ArrowLeft":
            this.prev();
            break;
          case "k":
          case "ArrowRight":
            this.next();
            break;
          case "a":
          case "Enter":
            this.archive();
            break;
        }
      });

      window.addEventListener("online", () => {
        this.syncPendingArchives();
      });

      const perPageInput = document.getElementById("settings-per-page");
      const daysInput = document.getElementById("settings-days");
      if (perPageInput) perPageInput.value = this.perPage || "";
      if (daysInput) daysInput.value = this.days || "";

      perPageInput?.addEventListener("change", (e) => {
        const v = e.target.value.trim();
        this.perPage = v || null;
        setCookie(COOKIE_PER_PAGE, v);
        this.fetchArticles(1);
      });
      daysInput?.addEventListener("change", (e) => {
        const v = e.target.value.trim();
        this.days = v || null;
        setCookie(COOKIE_DAYS, v);
        this.fetchArticles(1);
      });
    },

    toggleSettings: function () {
      const panel = document.getElementById("settings-panel");
      if (panel) {
        panel.style.display = panel.style.display === "none" ? "block" : "none";
      }
    },

    escapeHtml: function (text) {
      if (!text) return "";
      const div = document.createElement("div");
      div.textContent = text;
      return div.innerHTML;
    },

    formatDate: function (dateString) {
      if (!dateString) return "";
      const date = new Date(dateString);
      return date.toLocaleString();
    },

    getRootDomain: function (hostname) {
      const parts = hostname.split(".");
      return parts.slice(-2).join(".");
    },

    isInternalUrl: function (url) {
      try {
        const urlHost = new URL(url).hostname;
        const currentHost = window.location.hostname;
        return this.getRootDomain(urlHost) === this.getRootDomain(currentHost);
      } catch (e) {
        return false;
      }
    },

    fetchArticles: function (page) {
      if (this.loading) return;
      this.loading = true;

      let url = "/admin/reading_list/articles?page=" + page;
      if (this.days) {
        url += "&days=" + this.days;
      }
      if (this.perPage) {
        url += "&per_page=" + this.perPage;
      }

      fetch(url)
        .then((response) => response.json())
        .then((data) => {
          this.loading = false;
          this.processArticlesData(data, page);
          // Cache first page for offline use
          if (page === 1) {
            this.cacheArticles(data);
          }
        })
        .catch((error) => {
          this.loading = false;
          console.error("Error fetching articles:", error);

          // Try to load from cache when offline
          if (page === 1) {
            const cached = this.getCachedArticles();
            if (cached) {
              console.log("Loading from cache");
              this.processArticlesData(cached, page);
              return;
            }
          }

          document.getElementById("reading-list-content").innerHTML =
            "<p>Error loading articles. You appear to be offline.</p>";
        });
    },

    processArticlesData: function (data, page) {
      this.currentPage = data.page;
      this.hasMore = data.has_more;

      const pending = this.getPendingArchives();
      const filteredItems = data.items.filter(
        (item) => !pending.includes(item.id),
      );
      this.total = data.total - pending.length;

      if (page === 1) {
        this.articles = filteredItems;
        this.currentIndex = 0;
        this.openScrapeFeeds(data.scrape_feeds);
      } else {
        this.articles = this.articles.concat(filteredItems);
      }

      if (this.articles.length === 0) {
        document.getElementById("reading-list-content").innerHTML =
          "<p>No articles to read.</p>";
        this.renderSidebar();
        return;
      }

      // Prefetch descriptions for all new articles
      this.prefetchDescriptions(filteredItems);

      this.renderSidebar();
      this.renderArticle(this.currentIndex);
    },

    prefetchDescriptions: function (articles) {
      articles.forEach((article) => {
        if (article.description === undefined) {
          fetch("/admin/reading_list/article?id=" + article.id)
            .then((response) => response.json())
            .then((data) => {
              article.description = data.description;
            })
            .catch((e) => {
              console.error("Error prefetching article:", e);
            });
        }
      });
    },

    renderSidebar: function () {
      const sidebar = document.getElementById("reading-list-sidebar");
      if (this.articles.length === 0) {
        sidebar.innerHTML =
          "<p style='padding: 10px; color: #666;'>No articles</p>";
        return;
      }

      sidebar.innerHTML = this.articles
        .map(
          (article, index) => `
          <div class="sidebar-item" data-index="${index}" style="padding: 10px 15px; cursor: pointer; border-bottom: 1px solid #ddd; position: relative; background: ${index === this.currentIndex ? "#ddd; font-weight: bold;" : "#fff"}" onmouseover="this.style.background='#ccc'" onmouseout="this.style.background='${index === this.currentIndex ? "#ddd" : "#fff"}'">
            <div style="font-size: 13px; white-space: nowrap; pointer-events: none;">${this.escapeHtml(article.title || "Untitled").replace(article.feed_title + " - ", "")}</div>
            <div style="font-size: 11px; color: #888; margin-top: 3px; pointer-events: none;">${this.escapeHtml(article.feed_title || "")}</div>
            <span class="sidebar-archive" data-index="${index}" style="position: absolute; right: 10px; top: 75%; transform: translateY(-50%); cursor: pointer; font-size: 24px; padding: 2px;" title="Archive">📁</span>
          </div>
        `,
        )
        .join("");
    },

    renderArticle: async function (index) {
      if (index < 0 || index >= this.articles.length) return;

      const requestId = ++this._renderRequestId;
      const data = this.articles[index];
      document.getElementById("article-title").textContent =
        data.title || "Untitled";

      const contentDiv = document.getElementById("reading-list-content");
      const useDescription = data.sent_to != "" || this.isInternalUrl(data.url);

      const header = `
        <div style="margin-bottom: 20px; padding-bottom: 10px; border-bottom: 1px solid #eee;">
          <h1 style="margin: 0 0 10px 0;"><a href="${this.escapeHtml(data.url)}" target="_blank" rel="noopener noreferrer" style="color: inherit;">${this.escapeHtml(data.title)}</a></h1>
          <div style="color: #666; font-size: 14px;">
            ${data.feed_title ? "<span>" + this.escapeHtml(data.feed_title) + "</span> | " : ""}
            ${data.author ? "<span>" + this.escapeHtml(data.author) + "</span> | " : ""}
            ${data.published_at ? "<span>" + this.escapeHtml(this.formatDate(data.published_at)) + "</span>" : ""}
          </div>
        </div>
      `;

      if (useDescription) {
        // Fetch description if not already loaded
        if (data.description === undefined) {
          contentDiv.innerHTML = header + "<p>Loading...</p>";
          try {
            const response = await fetch(
              "/admin/reading_list/article?id=" + data.id,
            );
            if (this._renderRequestId !== requestId) return;
            const fullData = await response.json();
            data.description = fullData.description;
          } catch (e) {
            if (this._renderRequestId !== requestId) return;
            console.error("Error fetching article:", e);
            data.description = "<p>Failed to load article content.</p>";
          }
        }

        contentDiv.innerHTML = header;
        const iframe = document.createElement("iframe");
        iframe.srcdoc = '<base target="_blank">' + (data.description || "");
        iframe.style.cssText =
          "width:100%;height:calc(100vh - 200px);border:none;";
        iframe.sandbox = "allow-popups allow-popups-to-escape-sandbox";
        contentDiv.appendChild(iframe);
      } else {
        contentDiv.innerHTML =
          header +
          `
          <iframe src="${this.escapeHtml(data.url)}" style="width: 100%; height: calc(100vh - 150px); border: none;"></iframe>
        `;
        contentDiv.scrollTop = 0;
      }

      // Prefetch next page if we're near the end
      if (this.hasMore && index >= this.articles.length - 10) {
        this.fetchArticles(this.currentPage + 1);
      }
    },

    toggleSidebar: function () {
      this.sidebarCollapsed = !this.sidebarCollapsed;
      const sidebar = document.getElementById("reading-list-sidebar");
      const content = document.getElementById("reading-list-content");

      if (this.sidebarCollapsed) {
        sidebar.style.display = "none";
        content.style.marginLeft = "20px";
      } else {
        sidebar.style.display = "block";
        content.style.marginLeft = "270px";
      }
    },

    prev: function () {
      if (this.currentIndex > 0) {
        this.currentIndex--;
        this.renderSidebar();
        this.renderArticle(this.currentIndex);
      }
    },

    next: function () {
      if (this.currentIndex < this.articles.length - 1) {
        this.currentIndex++;
        this.renderSidebar();
        this.renderArticle(this.currentIndex);
      } else if (this.hasMore) {
        // Fetch more articles
        this.fetchArticles(this.currentPage + 1);
      }
    },

    archiveAtIndex: function (index) {
      if (index < 0 || index >= this.articles.length) return;

      const article = this.articles[index];
      const savedCurrentIndex = this.currentIndex;

      // Immediately update UI
      this.addPendingArchive(article.id);
      this.removeFromCache(article.id);
      this.articles.splice(index, 1);
      this.total--;

      // Adjust currentIndex if needed
      if (index < this.currentIndex) {
        this.currentIndex--;
      } else if (index === this.currentIndex) {
        if (
          this.currentIndex >= this.articles.length &&
          this.articles.length > 0
        ) {
          this.currentIndex = this.articles.length - 1;
        }
      }

      let canUndo = true;
      if (this.articles.length === 0) {
        if (this.hasMore) {
          canUndo = false;
          this.fetchArticles(this.currentPage + 1);
        } else {
          document.getElementById("reading-list-content").innerHTML =
            "<p>No more articles to read.</p>";
          document.getElementById("article-title").textContent = "";
          this.renderSidebar();
        }
      } else {
        this.renderSidebar();
        this.renderArticle(this.currentIndex);
      }

      if (this.archiveSyncTimeout) clearTimeout(this.archiveSyncTimeout);
      const self = this;
      if (canUndo) {
        this.showUndoToast("Archived", function () {
          self.undoArchive(article, index, savedCurrentIndex);
        });
        this.archiveSyncTimeout = setTimeout(function () {
          self.syncPendingArchives();
        }, 4000);
      } else {
        this.showToast("Archived");
        this.syncPendingArchives();
      }
    },

    archive: function () {
      if (this.articles.length === 0) return;

      const article = this.articles[this.currentIndex];
      const savedIndex = this.currentIndex;
      const savedCurrentIndex = this.currentIndex;

      // Immediately update UI
      this.addPendingArchive(article.id);
      this.removeFromCache(article.id);
      this.articles.splice(this.currentIndex, 1);
      this.total--;

      let canUndo = true;
      if (this.articles.length === 0) {
        if (this.hasMore) {
          canUndo = false;
          this.fetchArticles(this.currentPage + 1);
        } else {
          document.getElementById("reading-list-content").innerHTML =
            "<p>No more articles to read.</p>";
          document.getElementById("article-title").textContent = "";
          this.renderSidebar();
        }
      } else {
        if (this.currentIndex >= this.articles.length) {
          this.currentIndex = this.articles.length - 1;
        }
        this.renderSidebar();
        this.renderArticle(this.currentIndex);
      }

      if (this.archiveSyncTimeout) clearTimeout(this.archiveSyncTimeout);
      const self = this;
      if (canUndo) {
        this.showUndoToast("Archived", function () {
          self.undoArchive(article, savedIndex, savedCurrentIndex);
        });
        this.archiveSyncTimeout = setTimeout(function () {
          self.syncPendingArchives();
        }, 4000);
      } else {
        this.showToast("Archived");
        this.syncPendingArchives();
      }
    },

    addUrlFromClipboard: async function () {
      let url = null;

      // Try clipboard API first
      try {
        if (navigator.clipboard && navigator.clipboard.readText) {
          const text = await navigator.clipboard.readText();
          if (text && text.trim().match(/^https?:\/\//i)) {
            url = text.trim();
          }
        }
      } catch (e) {
        // Clipboard API failed, will fall back to prompt
      }

      // Fall back to prompt if clipboard didn't work
      if (!url) {
        url = prompt("Enter URL to add:");
        if (!url) return;
        url = url.trim();
      }

      if (!url.match(/^https?:\/\//i)) {
        alert("Invalid URL");
        return;
      }

      const csrfToken = document.querySelector(
        'meta[name="csrf-token"]',
      )?.content;

      try {
        const response = await fetch("/admin/reading_list/add_url", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken,
          },
          body: JSON.stringify({ url: url }),
        });

        const data = await response.json();

        if (data.success) {
          this.showToast(data.created ? "URL added" : "URL already exists");
          //this.fetchArticles(1);
        } else {
          alert("Failed to add URL: " + (data.error || "Unknown error"));
        }
      } catch (error) {
        console.error("Error adding URL:", error);
        alert("Failed to add URL: " + error.message);
      }
    },
  };

  ReadingListController.init();
});
