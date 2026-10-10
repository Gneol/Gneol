// Gneol landing page interactions
(function () {
  "use strict";

  // Newsletter form
  var newsForm = document.getElementById("newsletter-form");
  var newsStatus = document.getElementById("newsletter-status");
  if (newsForm && newsStatus) {
    newsForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var email = document.getElementById("newsletter-email").value.trim();
      newsStatus.classList.remove("error");
      newsStatus.textContent = "Subscribing...";
      fetch("https://formsubmit.co/ajax/tentarclesai@gmail.com", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify({ email: email, _subject: "Gneol newsletter subscription" })
      })
        .then(function (r) { return r.json(); })
        .then(function (res) {
          if (res.success === "false" || res.error) throw new Error(res.message || "Error");
          newsStatus.textContent = "✓ Subscribed! Talk soon.";
          newsForm.reset();
        })
        .catch(function () {
          newsStatus.classList.add("error");
          newsStatus.textContent = "Failed to subscribe. Email us: tentarclesai@gmail.com";
        });
    });
  }

  // Copy-to-clipboard for the install command
  var copyBtn = document.getElementById("install-copy");
  function activeCopyText() {
    var active = document.querySelector(".install-panel.active code[data-copy]");
    return active ? active.getAttribute("data-copy") : "";
  }
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      var text = activeCopyText();
      if (!text) return;
      var done = function () {
        copyBtn.textContent = "Copied";
        copyBtn.classList.add("copied");
        setTimeout(function () {
          copyBtn.textContent = "Copy";
          copyBtn.classList.remove("copied");
        }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done).catch(done);
      } else {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); } catch (e) {}
        document.body.removeChild(ta);
        done();
      }
    });
  }

  // Install tab switching
  var tabs = document.querySelectorAll(".tab");
  var panels = document.querySelectorAll(".install-panel");

  tabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      // Deactivate all tabs and panels
      tabs.forEach(function (t) { t.classList.remove("active"); });
      panels.forEach(function (p) { p.classList.remove("active"); });

      // Activate clicked tab + matching panel
      tab.classList.add("active");
      var panelId = "panel-" + tab.getAttribute("data-tab");
      var panel = document.getElementById(panelId);
      if (panel) panel.classList.add("active");
    });
  });
})();
