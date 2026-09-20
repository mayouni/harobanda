/* Harobanda site — mobile menu. No framework, no build. */
(function () {
  var nav = document.getElementById('nav');
  var mb = document.getElementById('menuBtn');
  if (mb && nav) mb.addEventListener('click', function () {
    var open = nav.classList.toggle('open');
    mb.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
})();
