// Tarayicinin lab CA'sina guvenip guvenmedigini dener: sertifika hatasi yok sayilmaz.
const { baslat, sayfa, GITLAB_URL } = require('./lib.cjs');
(async () => {
  const browser = await baslat();
  try {
    const page = await sayfa(browser);
    const yanit = await page.goto(`${GITLAB_URL}/users/sign_in`);
    console.log(`  tamam  ${GITLAB_URL} acildi: HTTP ${yanit.status()}, baslik "${await page.title()}"`);
    const sertifika = await yanit.securityDetails();
    console.log(`         sertifikayi veren: ${sertifika.issuer}`);
    console.log(`         testid: ${await page.locator('[data-testid]').evaluateAll((e) => [...new Set(e.map((x) => x.dataset.testid))].join(' '))}`);
  } catch (hata) {
    console.log(`  hata   ${String(hata.message).split('\n')[0]}`);
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
})();
