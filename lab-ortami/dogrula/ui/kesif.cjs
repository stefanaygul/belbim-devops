// Gelistirme araci (lab akisinin parcasi degildir): bir sayfanin form ogelerini dokup
// goruntusunu .cache/ui/kesif.png dosyasina yazar. Arayuz betikleri yazilirken secici bulmak icindir.
//   node kesif.cjs git <jenkins|sonar|gitlab-lead|gitlab-dev> <ekip> <yol> [adim ...]
//   adim: "Metin" (tikla) | css=<secici> (tikla) | sec=<secici>=>etiket | yaz=<secici>=>deger
const { GITLAB_URL, JENKINS_URL, SONAR_URL, ekip, giris, jenkinsGiris, sonarGiris, calistir } = require('./lib.cjs');
async function dok(page) {
  await page.waitForLoadState('networkidle').catch(() => {});
  console.log('URL', page.url(), '|', await page.title());
  const ogeler = await page.evaluate(() => {
    const gor = (el) => { const r = el.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
    const kisa = (t) => (t || '').replace(/\s+/g, ' ').trim().slice(0, 70);
    const out = [];
    document.querySelectorAll('input, select, textarea, button, a[role=button], [role=radio], [role=tab], [role=option], [role=menuitem]').forEach((el) => {
      if (!gor(el) && el.type !== 'radio' && el.type !== 'checkbox') return;
      const o = { t: el.tagName.toLowerCase() };
      for (const k of ['type', 'name', 'id', 'placeholder', 'aria-label', 'data-testid', 'role', 'value']) {
        const v = el.getAttribute(k); if (v && !(k === 'value' && el.type === 'password')) o[k] = kisa(v);
      }
      const txt = kisa(el.innerText); if (txt) o.txt = txt;
      if (el.tagName === 'SELECT') o.opts = [...el.options].map((x) => kisa(x.text)).slice(0, 14);
      if (el.labels && el.labels[0]) o.label = kisa(el.labels[0].innerText);
      out.push(JSON.stringify(o));
    });
    return out;
  });
  console.log(ogeler.slice(0, 160).join('\n'));
}
calistir({
  async git(browser, sistem, nn, yol, ...adimlar) {
    const e = ekip(nn);
    let page; let kok;
    if (sistem === 'jenkins') { page = await jenkinsGiris(browser, nn); kok = JENKINS_URL; }
    else if (sistem === 'sonar') { page = await sonarGiris(browser, nn); kok = SONAR_URL; }
    else { page = await giris(browser, sistem === 'gitlab-dev' ? e.dev : e.lead); kok = GITLAB_URL; }
    await page.goto(kok + yol);
    for (const t of adimlar) {
      if (t.startsWith('css=')) await page.locator(t.slice(4)).first().click();
      else if (t.startsWith('sec=')) { const [s, v] = t.slice(4).split('=>'); await page.locator(s).first().selectOption({ label: v }); }
      else if (t.startsWith('yaz=')) { const [s, v] = t.slice(4).split('=>'); await page.locator(s).first().fill(v); }
      else await page.getByText(t, { exact: true }).first().click();
      await page.waitForTimeout(800);
    }
    await dok(page);
    await page.screenshot({ path: '/lab/cikti/kesif.png', fullPage: true });
  },
});
