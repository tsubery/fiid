//= require active_admin/base

document.addEventListener("DOMContentLoaded", function () {
  const app = document.getElementById("reading-list-app");
  if (!app) return;

  const PENDING_ARCHIVES_KEY = "readingList.pendingArchives";
  const ARTICLES_CACHE_KEY = "readingList.articlesCache";

  const ReadingListController = {
    articles: [],
    currentIndex: 0,
    currentPage: 1,
    hasMore: false,
    total: 0,
    loading: false,
    days: null,
    perPage: null,
    syncing: false,
    sidebarCollapsed: false,

    init: function () {
      const urlParams = new URLSearchParams(window.location.search);
      this.days = urlParams.get("days") || null;
      this.perPage = urlParams.get("per_page") || null;
      this.bindEvents();
      this.syncPendingArchives();
      this.fetchArticles(1);
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
            const fullData = await response.json();
            data.description = fullData.description;
          } catch (e) {
            console.error("Error fetching article:", e);
            data.description = "<p>Failed to load article content.</p>";
          }
        }

        const sanitizedDescription =
          typeof DOMPurify !== "undefined"
            ? DOMPurify.sanitize(data.description || "")
            : this.escapeHtml(data.description || "");

        contentDiv.innerHTML =
          header + `<div class="article-body">${sanitizedDescription}</div>`;
        contentDiv.scrollTop = 0;

        contentDiv.querySelectorAll(".article-body a").forEach((link) => {
          link.setAttribute("target", "_blank");
          link.setAttribute("rel", "noopener noreferrer");
        });
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

      if (this.articles.length === 0) {
        if (this.hasMore) {
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

      // Sync in background
      this.syncPendingArchives();
    },

    archive: function () {
      if (this.articles.length === 0) return;

      const article = this.articles[this.currentIndex];

      // Immediately update UI
      this.addPendingArchive(article.id);
      this.removeFromCache(article.id);
      this.articles.splice(this.currentIndex, 1);
      this.total--;

      if (this.articles.length === 0) {
        if (this.hasMore) {
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

      // Sync in background
      this.syncPendingArchives();
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
          this.fetchArticles(1);
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
