/* Harobanda site — theme toggle + mobile menu. No framework, no build. */
(function () {
  var root = document.documentElement;
  var KEY = 'harobanda-theme';
  var tbtn = document.getElementById('themeBtn');

  function sysDark() {
    try { return matchMedia('(prefers-color-scheme:dark)').matches; } catch (e) { return false; }
  }
  try {
    var s = localStorage.getItem(KEY);
    if (s === 'dark' || s === 'light') root.setAttribute('data-theme', s);
  } catch (e) {}

  function tlabel() {
    var c = root.getAttribute('data-theme') || (sysDark() ? 'dark' : 'light');
    if (tbtn) tbtn.textContent = c === 'dark' ? 'Light' : 'Dark';
  }
  tlabel();

  if (tbtn) tbtn.addEventListener('click', function () {
    var c = root.getAttribute('data-theme') || (sysDark() ? 'dark' : 'light');
    var n = c === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', n);
    try { localStorage.setItem(KEY, n); } catch (e) {}
    tlabel();
  });

  var nav = document.getElementById('nav');
  var mb = document.getElementById('menuBtn');
  if (mb && nav) mb.addEventListener('click', function () {
    var open = nav.classList.toggle('open');
    mb.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
})();
