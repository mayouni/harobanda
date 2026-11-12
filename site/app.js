/* Harobanda site — mobile menu, and the menu over the home page's photograph.
   No framework, no build. */
(function () {
  var nav = document.getElementById('nav');
  var mb = document.getElementById('menuBtn');
  if (mb && nav) mb.addEventListener('click', function () {
    var open = nav.classList.toggle('open');
    mb.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
})();

/* Every page but the home and the Blog's has the section strip under the menu, and
   the strip stays on screen when the page scrolls, directly under the menu. Its CSS top is
   the menu's height as CSS computes it (--bar-h); this writes the menu's measured
   height over that number, and the strip's own height beside it, so the two bars
   meet with no gap at any zoom and a jump to an anchor lands below both. */
(function () {
  var path = document.querySelector('.path');
  var bar = document.querySelector('.bar');
  if (!path || !bar) return;
  var root = document.documentElement;
  var place = function () {
    root.style.setProperty('--bar-h', bar.getBoundingClientRect().height + 'px');
    root.style.setProperty('--path-h', path.getBoundingClientRect().height + 'px');
  };
  place();
  window.addEventListener('resize', place);
  window.addEventListener('load', place);
})();

/* The home page (the Softanza site's recipe): the photograph starts at the top of
   the browser, under the menu, and the menu is white letters over it until the
   reader has scrolled past it. CSS already pulls the picture up by --bar-h, so it
   is right without this script. The script says when the picture is behind the
   menu, and only if the picture did not land at the very top (the bar came out
   taller than CSS expects) does it write the bar's real height over CSS's number. */
(function () {
  var hero = document.querySelector('.home-body .hero-photo');
  var img = document.querySelector('.home-body .hero-img');
  var bar = document.querySelector('.bar');
  if (!hero || !img || !bar) return;
  var root = document.documentElement;
  var state = function () {
    var behind = img.getBoundingClientRect().bottom > bar.getBoundingClientRect().bottom + 8;
    document.body.classList.toggle('over-hero', behind);
  };
  /* The Radar bar, when it shows, is inserted above the menu and pushes the page
     down by its height; that height is written as --radar-h, and the picture gives
     it up (styles.css), so the hero stays whole in the first screen. The bar
     arrives after the page, and shrinks to nothing when dismissed: both are
     watched, never assumed. */
  var radar = null, watching = null;
  var radarH = function () {
    radar = radar && radar.isConnected ? radar : document.querySelector('[data-radar-bar]');
    if (radar && radar !== watching && window.ResizeObserver) {
      watching = radar;
      new ResizeObserver(function () { place(); }).observe(radar);
    }
    return radar ? Math.round(radar.getBoundingClientRect().height) : 0;
  };
  var place = function () {
    var r = radarH();
    if (r > 0) root.style.setProperty('--radar-h', r + 'px');
    else root.style.removeProperty('--radar-h');
    root.style.removeProperty('--bar-h');
    if (Math.abs(hero.getBoundingClientRect().top + window.scrollY - r) > 1.5)
      root.style.setProperty('--bar-h', Math.round(bar.getBoundingClientRect().height) + 'px');
    state();
  };
  place();
  if (window.MutationObserver)
    new MutationObserver(function () { if (!watching) place(); })
      .observe(document.body, { childList: true });
  window.addEventListener('resize', place);
  window.addEventListener('load', place);
  window.addEventListener('scroll', state, { passive: true });
})();

/* The foot's end year is computed, never typed (PRINCIPAL-COPYRIGHTYEARS-01): the
   site's build writes the year it was built, and this writes the year it is read. */
(function () {
  var y = String(new Date().getFullYear());
  var spans = document.querySelectorAll('.year');
  for (var i = 0; i < spans.length; i++) spans[i].textContent = y;
})();
