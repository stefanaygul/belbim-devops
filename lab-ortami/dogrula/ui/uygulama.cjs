// Saha Ekipman Talep Portali arayuzu: katalog listeleniyor mu, talep olusturulabiliyor mu?
//   node uygulama.cjs talep <url> <goruntu-adi> [urun-kodu] [miktar]
//   node uygulama.cjs katalog <url> <goruntu-adi> [beklenen-metin ...]
//   node uygulama.cjs red <url> <goruntu-adi> <urun-kodu> <miktar> <beklenen-hata>
const { expect } = require('playwright/test');
const { sayfa, goruntu, tamam, calistir } = require('./lib.cjs');

async function ac(browser, url) {
  const page = await sayfa(browser);
  await page.goto(url);
  await expect(page.getByRole('heading', { name: 'Saha Ekipman Talep Portalı' })).toBeVisible();
  await expect(page.locator('section[aria-labelledby="catalog-title"]').getByRole('cell', { name: 'ADP-01', exact: true })).toBeVisible();
  const satir = await page.locator('section[aria-labelledby="catalog-title"] tbody tr').count();
  tamam(`katalog listeleniyor: ${satir} ekipman (${url})`);
  return page;
}

calistir({
  // Katalogu acar; verilen metinlerin sayfada gorundugunu denetler.
  async katalog(browser, url, ad, ...metinler) {
    const page = await ac(browser, url);
    for (const metin of metinler) {
      await expect(page.getByText(metin).first()).toBeVisible();
      tamam(`gorunuyor: ${metin}`);
    }
    await goruntu(page, ad);
  },

  // Formdan talep olusturur ve talebin listeye dustugunu denetler.
  async talep(browser, url, ad, urun = 'ADP-01', miktar = '2') {
    const page = await ac(browser, url);
    await page.getByRole('combobox', { name: 'Ekipman' }).selectOption(urun);
    await page.getByRole('spinbutton', { name: 'Miktar' }).fill(String(miktar));
    await page.getByRole('button', { name: 'Talep oluştur' }).click();
    await expect(page.getByRole('status')).toHaveText('Talep oluşturuldu.');
    const liste = page.locator('section[aria-labelledby="order-list-title"]');
    await expect(liste.getByText(urun).first()).toBeVisible();
    tamam(`talep olusturuldu: ${urun} x ${miktar}`);
    await goruntu(page, ad, { fullPage: true });
  },

  // Gecersiz talep: API'nin hata mesaji formun altinda gorunur; talep listeye eklenmez.
  async red(browser, url, ad, urun, miktar, beklenen) {
    const page = await ac(browser, url);
    const liste = page.locator('section[aria-labelledby="order-list-title"] tbody tr');
    const once = await liste.count();
    await page.getByRole('combobox', { name: 'Ekipman' }).selectOption(urun);
    await page.getByRole('spinbutton', { name: 'Miktar' }).fill(String(miktar));
    await page.getByRole('button', { name: 'Talep oluştur' }).click();
    await expect(page.getByRole('alert')).toHaveText(beklenen);
    await page.waitForTimeout(1000);
    expect(await liste.count()).toBe(once);
    tamam(`talep reddedildi: ${urun} x ${miktar} -> "${beklenen}"`);
    await goruntu(page, ad, { fullPage: true });
  },
});
