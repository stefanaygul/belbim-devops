// Nexus arayuz adimlari (Playwright). Her komut ogrenci rehberindeki bir arayuz adimidir.
//   node nexus.cjs <komut> <ekip> [arguman ...]
// Giris ekip kullanicisiyla (ekipNN) yapilir. API anahtari ekrana yazilmaz; yalnizca
// .cache/ui/token-ekipNN-nexus dosyasina kaydedilir ve goruntude maskelenir.
const { expect } = require('playwright/test');
const { D, parola, ekip, sayfa, tokenYaz, goruntu, tamam, calistir } = require('./lib.cjs');

const NEXUS_URL = `https://nexus.${D}`;
const ANAHTAR = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/;

async function nexusGiris(browser, nn) {
  const e = ekip(nn);
  const page = await sayfa(browser);
  await page.goto(`${NEXUS_URL}/`);
  await page.getByRole('button', { name: 'Log In' }).or(page.getByRole('link', { name: 'Log In' })).first().click();
  await page.locator('#username, input[name="username"]').first().fill(`ekip${e.no}`);
  await page.locator('#password, input[name="password"]').first().fill(parola(`nexus-ekip${e.no}`));
  await page.getByRole('button', { name: 'Log in' }).click();
  await expect(page.getByRole('button', { name: 'Account settings, tokens and keys' })).toBeVisible();
  return page;
}

calistir({
  // Hesap menusu > NuGet API Key > Access API Key (gerekirse parola yeniden sorulur)
  async 'api-anahtari'(browser, nn, ad) {
    const e = ekip(nn);
    const page = await nexusGiris(browser, nn);
    await page.getByRole('button', { name: 'Account settings, tokens and keys' }).click();
    // Menu ogesi radix menusunde; erisilebilir adi yok, metniyle bulunur (kesifte boyle calisti).
    await page.getByText('NuGet API Key', { exact: true }).first().click();
    await expect(page.getByRole('button', { name: 'Access API Key' })).toBeVisible();
    await goruntu(page, `${ad}-sayfa`);
    await page.getByRole('button', { name: 'Access API Key' }).click();
    // Nexus parolayi yeniden sorar ("Authenticate" penceresi tiklamadan sonra gecikmeli acilir).
    const kod = page.locator('code:visible').filter({ hasText: ANAHTAR });
    const parolaAlani = page.locator('input[type="password"]:visible');
    await expect(kod.first().or(parolaAlani.first())).toBeVisible({ timeout: 20000 });
    if (await parolaAlani.count()) {
      await goruntu(page, `${ad}-parola`);
      await parolaAlani.first().fill(parola(`nexus-ekip${e.no}`));
      await page.getByRole('button', { name: 'Authenticate', exact: true }).click();
    }
    await expect(kod.first()).toBeVisible({ timeout: 20000 });
    const deger = (await kod.first().innerText()).match(ANAHTAR)[0];
    tokenYaz(`ekip${e.no}-nexus`, deger);
    tamam(`ekip${e.no}: NuGet API anahtari alindi (deger ekrana yazilmadi)`);
    // Anahtar sayfanin birden cok yerinde (kullanim komutlari dahil) gecer. Goruntuden once
    // butun metin dugumlerinde ve alanlarda degistirilir; ardindan denetlenir.
    const kalan = await page.evaluate((anahtar) => {
      const yerine = (t) => t.split(anahtar).join('••••••••-••••-••••-••••-••••••••••••');
      const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      while (w.nextNode()) if (w.currentNode.nodeValue.includes(anahtar)) w.currentNode.nodeValue = yerine(w.currentNode.nodeValue);
      document.querySelectorAll('input, textarea').forEach((x) => { if (x.value.includes(anahtar)) x.value = yerine(x.value); });
      return document.documentElement.outerHTML.includes(anahtar) || document.body.innerText.includes(anahtar);
    }, deger);
    if (kalan) throw new Error('anahtar sayfadan silinemedi; goruntu alinmadi');
    await goruntu(page, ad, { mask: [page.getByText(ANAHTAR)] });
  },

  // Browse > nuget-hosted: ekibin paketi ve surumu
  async 'paket'(browser, nn, surum, ad) {
    const e = ekip(nn);
    const page = await nexusGiris(browser, nn);
    const paketAdi = `Saha.Common.Contracts.Ekip${e.no}`;
    await page.goto(`${NEXUS_URL}/#browse/browse:nuget-hosted`);
    await page.waitForLoadState('networkidle').catch(() => {});
    await expect(page.getByText(paketAdi).first()).toBeVisible({ timeout: 20000 });
    // Cift tiklama, agacin ilk yuklenmesinde acilip tekrar kapanmasina yol acabiliyor.
    // Klasorun kendi + simgesine bir kez bas; surum satirini secip detayini bekle.
    const klasor = page.locator('tr[role="row"]').filter({ has: page.getByText(paketAdi, { exact: true }) });
    const surumSatiri = page.getByText(surum, { exact: true }).first();
    if (!await surumSatiri.isVisible()) await klasor.locator('.x-tree-expander').click();
    await expect(surumSatiri).toBeVisible({ timeout: 15000 });
    await surumSatiri.click();
    await expect(page.getByText(`${paketAdi}/${surum}`, { exact: true })).toBeVisible({ timeout: 15000 });
    tamam(`nuget-hosted: ${paketAdi} ${surum}`);
    await goruntu(page, ad);
  },
});
