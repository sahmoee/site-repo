(() => {
  const toggle = document.querySelector('.nav-toggle');
  const navigation = document.querySelector('.nav-links');
  if (toggle && navigation) {
    if (!navigation.id) navigation.id = 'primary-navigation';
    toggle.setAttribute('aria-controls', navigation.id);
    if (!toggle.getAttribute('aria-label')) toggle.setAttribute('aria-label', 'Toggle navigation');
    const collapsed = () => getComputedStyle(toggle).display !== 'none';
    const setOpen = open => {
      navigation.classList.toggle('open', open);
      toggle.setAttribute('aria-expanded', String(open));
      navigation.inert = collapsed() && !open;
    };
    setOpen(false);
    toggle.addEventListener('click', () => setOpen(!navigation.classList.contains('open')));
    navigation.querySelectorAll('a').forEach(link => link.addEventListener('click', () => setOpen(false)));
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && navigation.classList.contains('open')) {
        setOpen(false);
        toggle.focus();
      }
    });
    document.addEventListener('click', event => {
      if (!navigation.contains(event.target) && !toggle.contains(event.target)) setOpen(false);
    });
    window.addEventListener('resize', () => setOpen(false));
  }
  document.querySelectorAll('[data-year]').forEach(element => { element.textContent = new Date().getFullYear(); });
})();
