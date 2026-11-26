// SonarQube arayuz adimlari (Playwright). Her komut ogrenci rehberindeki bir arayuz adimidir.
//   node sonar.cjs <komut> <ekip> [arguman ...]
// Giris ekip kullanicisiyla (ekipNN) yapilir. Token degeri ekrana yazilmaz; yalnizca
// .cache/ui/token-<ad> dosyasina kaydedilir ve goruntude maskelenir.
const { expect } = require('playwright/test');
const { SONAR_URL, ekip, sonarGiris, tokenYaz, goruntu, tamam, calistir } = require('./lib.cjs');

const anahtar = (e) => `saha-portal-ekip${e.no}`;
// Tanitim kutusu goruntuleri kapatmasin.
async function kutuyuKapat(page) {
  await page.waitForLoadState('networkidle').catch(() => {});
  const dugme = page.getByRole('button', { name: 'Dismiss' });
  await dugme.first().click({ timeout: 4000 }).catch(() => {});
}
// Acilir listeden (combobox) secenek secer.
async function sec(page, kutu, secenek) {
  // react-select: gorunur giris alani yoktur; odaklanip klavyeyle acilir.
  await kutu.focus();
  await page.keyboard.press('ArrowDown');
  await page.getByRole('option', { name: secenek }).first().click();
}

calistir({
  // Projects > Create Project > Local project: ad ve anahtar saha-portal-ekipNN, ana branch develop
  async proje(browser, nn, ad) {
    const e = ekip(nn);
    const page = await sonarGiris(browser, nn);
    await page.goto(`${SONAR_URL}/projects/create?mode=manual`);
    await kutuyuKapat(page);
    await page.locator('#project-name').fill(anahtar(e));
    await expect(page.locator('#project-key')).toHaveValue(anahtar(e));
    await page.locator('#main-branch-name').fill('develop');
    await goruntu(page, `${ad}-form`);
    await page.getByRole('button', { name: 'Next' }).click();
    // 2. adim: yeni kod tanimi (New Code) - kurum varsayilani
    await page.getByText(/Follows the instance.s default/).click();
    await expect(page.getByText('Current default: Previous version')).toBeVisible();
    await goruntu(page, `${ad}-yeni-kod`);
    await page.getByRole('button', { name: 'Create project' }).click();
    await page.waitForURL((u) => u.search.includes(`id=${anahtar(e)}`));
    await page.waitForLoadState('networkidle').catch(() => {});
    tamam(`SonarQube projesi olusturuldu: ${anahtar(e)} (ana branch develop, yeni kod: kurum varsayilani)`);
    await goruntu(page, ad);
  },

  // My Account > Security > Generate Tokens: Project Analysis Token
  async token(browser, nn, tokenAdi, ad) {
    const e = ekip(nn);
    const page = await sonarGiris(browser, nn);
    await page.goto(`${SONAR_URL}/account/security`);
    await kutuyuKapat(page);
    await page.locator('#token-name').fill(tokenAdi);
    await sec(page, page.locator('#token-select-type'), 'Project Analysis Token');
    await sec(page, page.locator('#token-select-project'), anahtar(e));
    await sec(page, page.locator('#token-select-expiration'), '30 days');
    await goruntu(page, `${ad}-form`);
    await page.getByRole('button', { name: 'Generate', exact: true }).click();
    await expect(page.getByText(/has been created/i).first()).toBeVisible();
    const deger = (await page.locator('body').innerText()).match(/sqp_[0-9a-f]{20,}/);
    if (!deger) throw new Error('token degeri sayfada bulunamadi');
    tokenYaz(`ekip${e.no}-sonar`, deger[0]);
    tamam(`SonarQube token'i uretildi: ${tokenAdi} (Project Analysis Token, ${anahtar(e)}); deger yalnizca bir kez gosterilir`);
    await goruntu(page, ad, { mask: [page.getByText(deger[0])] });
  },

  // Proje sayfasini acar, beklenen metinleri denetler, goruntu alir. yol: /dashboard, /project/activity ...
  async sayfa(browser, nn, yol, beklenen, ad) {
    const e = ekip(nn);
    const page = await sonarGiris(browser, nn);
    await page.goto(`${SONAR_URL}${yol}${yol.includes('?') ? '&' : '?'}id=${anahtar(e)}`);
    await page.waitForLoadState('networkidle').catch(() => {});
    await kutuyuKapat(page);
    for (const metin of beklenen.split('|').filter(Boolean)) {
      await expect(page.getByText(metin).locator('visible=true').first()).toBeVisible();
      tamam(`gorunuyor: ${metin}`);
    }
    await goruntu(page, ad);
  },
});
