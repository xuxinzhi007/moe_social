(function () {
  "use strict";

  var FEEDBACK_API = (function () {
    var host = window.location.hostname;
    if (host === "localhost" || host === "127.0.0.1") {
      return "http://127.0.0.1:8888";
    }
    return "http://47.106.175.49:8888";
  })();

  var prefersReduced =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* Scroll progress */
  var progressBar = document.getElementById("scrollProgress");
  function onScroll() {
    var doc = document.documentElement;
    var scrollTop = doc.scrollTop || document.body.scrollTop;
    var height = doc.scrollHeight - doc.clientHeight;
    var p = height > 0 ? (scrollTop / height) * 100 : 0;
    if (progressBar) progressBar.style.width = p + "%";

    var nav = document.getElementById("nav");
    if (nav) nav.classList.toggle("is-scrolled", scrollTop > 24);
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* Nav mobile */
  var menuBtn = document.getElementById("menuBtn");
  var nav = document.getElementById("nav");
  if (menuBtn && nav) {
    menuBtn.addEventListener("click", function () {
      nav.classList.toggle("is-open");
    });
    nav.querySelectorAll('a[href^="#"]').forEach(function (a) {
      a.addEventListener("click", function () {
        nav.classList.remove("is-open");
      });
    });
  }

  /* Year */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  /* Reveal on scroll */
  if (!prefersReduced && "IntersectionObserver" in window) {
    var revealEls = document.querySelectorAll(".reveal");
    var revealIo = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            revealIo.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    revealEls.forEach(function (el) {
      revealIo.observe(el);
    });
  } else {
    document.querySelectorAll(".reveal").forEach(function (el) {
      el.classList.add("is-visible");
    });
  }

  /* Hero phone parallax */
  var phoneStage = document.getElementById("phoneStage");
  if (phoneStage && !prefersReduced && window.matchMedia("(pointer: fine)").matches) {
    document.addEventListener("mousemove", function (e) {
      var cx = window.innerWidth / 2;
      var cy = window.innerHeight / 2;
      var rx = ((e.clientY - cy) / cy) * -8;
      var ry = ((e.clientX - cx) / cx) * 10;
      phoneStage.style.transform =
        "rotateX(" + rx + "deg) rotateY(" + ry + "deg) translateZ(0)";
    });
    document.body.classList.add("has-pointer");
    var glow = document.getElementById("cursorGlow");
    if (glow) {
      document.addEventListener("mousemove", function (e) {
        glow.style.left = e.clientX + "px";
        glow.style.top = e.clientY + "px";
      });
    }
  }

  /* Bento card spotlight */
  document.querySelectorAll(".bento-card").forEach(function (card) {
    card.addEventListener("mousemove", function (e) {
      var rect = card.getBoundingClientRect();
      var mx = ((e.clientX - rect.left) / rect.width) * 100;
      var my = ((e.clientY - rect.top) / rect.height) * 100;
      card.style.setProperty("--mx", mx + "%");
      card.style.setProperty("--my", my + "%");
    });
  });

  /* Story step switcher */
  var storySteps = document.querySelectorAll(".story__step");
  var storySlides = document.querySelectorAll(".story__slide");
  function setStory(index) {
    storySteps.forEach(function (step, i) {
      step.classList.toggle("is-active", i === index);
    });
    storySlides.forEach(function (slide, i) {
      slide.classList.toggle("is-active", i === index);
    });
  }
  storySteps.forEach(function (step, i) {
    step.addEventListener("click", function () {
      setStory(i);
    });
    step.addEventListener("mouseenter", function () {
      if (window.matchMedia("(pointer: fine)").matches) setStory(i);
    });
  });
  if (storySteps.length) setStory(0);

  /* Auto-advance story when in view */
  if (!prefersReduced && storySteps.length && "IntersectionObserver" in window) {
    var storySection = document.getElementById("story");
    var storyIndex = 0;
    var storyTimer;
    function startStoryTimer() {
      clearInterval(storyTimer);
      storyTimer = setInterval(function () {
        storyIndex = (storyIndex + 1) % storySteps.length;
        setStory(storyIndex);
      }, 4500);
    }
    var storyIo = new IntersectionObserver(
      function (entries) {
        if (entries[0].isIntersecting) startStoryTimer();
        else clearInterval(storyTimer);
      },
      { threshold: 0.35 }
    );
    if (storySection) storyIo.observe(storySection);
    storySteps.forEach(function (step, i) {
      step.addEventListener("click", function () {
        storyIndex = i;
        startStoryTimer();
      });
    });
  }

  /* Stat counter */
  function animateValue(el, target, suffix) {
    var start = 0;
    var duration = 1400;
    var startTime = null;
    suffix = suffix || "";
    function step(ts) {
      if (!startTime) startTime = ts;
      var progress = Math.min((ts - startTime) / duration, 1);
      var eased = 1 - Math.pow(1 - progress, 3);
      el.textContent = Math.floor(eased * target) + suffix;
      if (progress < 1) requestAnimationFrame(step);
      else el.textContent = target + suffix;
    }
    requestAnimationFrame(step);
  }
  var statEls = document.querySelectorAll("[data-count]");
  if (statEls.length && !prefersReduced && "IntersectionObserver" in window) {
    var statIo = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          var n = parseInt(el.getAttribute("data-count"), 10);
          var suffix = el.getAttribute("data-suffix") || "";
          animateValue(el, n, suffix);
          statIo.unobserve(el);
        });
      },
      { threshold: 0.5 }
    );
    statEls.forEach(function (el) {
      statIo.observe(el);
    });
  }

  /* Feedback form */
  var card = document.getElementById("feedbackCard");
  var form = document.getElementById("feedbackForm");
  if (form) {
    var statusEl = document.getElementById("fbStatus");
    var submitBtn = document.getElementById("fbSubmit");
    var contentEl = document.getElementById("fbContent");
    var charCountEl = document.getElementById("fbCharCount");

    function updateCharCount() {
      if (!contentEl || !charCountEl) return;
      var n = contentEl.value.length;
      charCountEl.textContent = n + " / 2000";
      charCountEl.style.color = n > 1900 ? "#b91c1c" : "";
    }
    if (contentEl) {
      contentEl.addEventListener("input", updateCharCount);
      updateCharCount();
    }

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (!statusEl || !submitBtn) return;
      statusEl.textContent = "";
      statusEl.className = "feedback-status";

      var email = document.getElementById("fbEmail").value.trim();
      var category = document.getElementById("fbCategory").value;
      var content = document.getElementById("fbContent").value.trim();

      if (!email || email.indexOf("@") < 1) {
        statusEl.textContent = "请填写有效的联系邮箱";
        statusEl.className = "feedback-status err";
        return;
      }
      if (content.length < 5) {
        statusEl.textContent = "反馈内容至少 5 个字";
        statusEl.className = "feedback-status err";
        return;
      }

      submitBtn.disabled = true;
      submitBtn.textContent = "提交中…";

      fetch(FEEDBACK_API + "/api/landing/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: email,
          category: category,
          content: content,
          source: "official-site",
        }),
      })
        .then(function (res) {
          return res.json().then(function (data) {
            return { ok: res.ok, data: data };
          });
        })
        .then(function (result) {
          if (result.data && result.data.success) {
            statusEl.textContent = result.data.message || "感谢你的反馈，我们会认真阅读 ✨";
            statusEl.className = "feedback-status ok";
            if (card) card.classList.add("submitted");
            form.reset();
            updateCharCount();
            window.setTimeout(function () {
              if (card) card.classList.remove("submitted");
            }, 2800);
            return;
          }
          statusEl.textContent =
            (result.data && result.data.message) || "提交失败，请稍后再试";
          statusEl.className = "feedback-status err";
        })
        .catch(function () {
          statusEl.textContent = "网络异常，请稍后再试或发送邮件";
          statusEl.className = "feedback-status err";
        })
        .finally(function () {
          submitBtn.disabled = false;
          submitBtn.textContent = "提交反馈";
        });
    });
  }
})();
