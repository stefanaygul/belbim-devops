// Jenkins arayuz adimlari (Playwright). Her komut ogrenci rehberindeki bir arayuz adimidir.
//   node jenkins.cjs <komut> <ekip> [arguman ...]
// Giris ekip kullanicisiyla (ekipNN) yapilir; yalnizca ekip-NN klasorunde calisilir.
// Token degerleri .cache/ui/token-<ad> dosyalarindan okunur; ekrana yazilmaz, goruntude maskelenir.
const { expect } = require('playwright/test');
const { GITLAB_URL, JENKINS_URL, ekip, jenkinsGiris, tokenOku, goruntu, tamam, calistir } = require('./lib.cjs');

const TURLER = {
  'gitlab-api': 'com.dabsquared.gitlabjenkins.connection.GitLabApiTokenImpl',
  userpass: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl',
  secret: 'org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl',
  ssh: 'com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey',
};
const klasor = (e) => `${JENKINS_URL}/job/ekip-${e.no}`;
const job = (e) => `${klasor(e)}/job/saha-portal-ekip${e.no}`;
// Kaydetmeden sonra job sayfasina donulmeli. Jenkins hata verirse adres .../configSubmit kalir
// ve sayfada "Oops!" yazar; bu durumda adim basarisiz sayilir.
async function kaydedildi(page, beklenenAdres) {
  await page.waitForURL((u) => !u.pathname.endsWith('/configure'));
  await page.waitForLoadState('networkidle').catch(() => {});
  const adres = page.url();
  if (adres.endsWith('/configSubmit') || (await page.getByText(/Oops!|A problem occurred/).count())) {
    throw new Error(`Jenkins kaydi reddetti (${adres}); controller logunu inceleyin`);
  }
  if (!adres.startsWith(beklenenAdres)) throw new Error(`beklenmeyen adres: ${adres}`);
}

const komutlar = {
  // Klasor > Credentials > Folder > Global > Add Credentials
  //   tur: gitlab-api | userpass | secret | ssh ; tokenAdi: .cache/ui/token-<tokenAdi> ;
  //   kullanici: userpass ve ssh icin (ssh: token dosyasi ozel anahtarin kendisidir)
  async credential(browser, nn, id, tur, tokenAdi, kullanici, aciklama, ad) {
    const e = ekip(nn);
    const deger = tokenOku(tokenAdi);
    const page = await jenkinsGiris(browser, nn);
    await page.goto(`${klasor(e)}/credentials/store/folder/domain/_/`);
    if (await page.getByRole('link', { name: id, exact: true }).count()) {
      tamam(`credential ${id} zaten var`);
      return;
    }
    await page.getByRole('button', { name: 'Add Credentials' }).click();
    const tip = page.locator(`input[name="kind"][value="${TURLER[tur]}"]`);
    await tip.check({ force: true });
    if (ad && tur === 'gitlab-api') await goruntu(page, `${ad}-tur`);
    await page.locator('#cr-dialog-next').click();
    const form = page.locator('dialog[open], .jenkins-dialog').last();
    let gizliAlan;
    if (tur === 'userpass') {
      await form.locator('input[name="_.username"]').fill(kullanici);
      gizliAlan = form.locator('input[name="_.password"]');
    } else if (tur === 'ssh') {
      await form.locator('input[name="_.username"]').fill(kullanici);
      await form.getByText('Enter directly', { exact: true }).click();
      const ekleDugme = form.getByRole('button', { name: 'Add', exact: true });
      if (await ekleDugme.count()) await ekleDugme.first().click();
      gizliAlan = form.locator('textarea[name="_.privateKey"]');
    } else if (tur === 'gitlab-api') {
      gizliAlan = form.locator('input[name="_.apiToken"]');
    } else {
      gizliAlan = form.locator('input[name="_.secret"]');
    }
    await gizliAlan.fill(tur === 'ssh' ? `${deger}\n` : deger);
    await form.locator('input[name="_.id"]').fill(id);
    await form.locator('input[name="_.description"]').fill(aciklama);
    if (ad) await goruntu(page, ad, { mask: [gizliAlan] });
    await page.locator('#cr-dialog-submit').click();
    await expect(page.getByRole('link', { name: id, exact: true })).toBeVisible();
    tamam(`credential ${id} (${tur}) ekip-${e.no} klasorune eklendi`);
  },

  // Klasordeki credential listesi
  async credentials(browser, nn, beklenen, ad) {
    const e = ekip(nn);
    const page = await jenkinsGiris(browser, nn);
    await page.goto(`${klasor(e)}/credentials/store/folder/domain/_/`);
    for (const id of beklenen.split(',')) {
      await expect(page.getByRole('link', { name: id, exact: true })).toBeVisible();
      tamam(`credential var: ${id}`);
    }
    await goruntu(page, ad);
  },

  // Klasor > New Item > Multibranch Pipeline; Branch Sources > Git (HTTPS, credential gitlab-repo)
  async multibranch(browser, nn, ad) {
    const e = ekip(nn);
    const isim = `saha-portal-ekip${e.no}`;
    const page = await jenkinsGiris(browser, nn);
    const var_ = await page.request.get(`${job(e)}/api/json`);
    if (var_.ok()) {
      tamam(`Multibranch Pipeline zaten var: ekip-${e.no}/${isim}`);
    } else {
      await komutlar.olustur(page, e, isim, ad);
    }
    // Ilk tarama: branch'ler bulunana kadar bekle (duz metin sayfasi kendiliginden yenilenmez)
    let log = '';
    for (let i = 0; i < 60; i += 1) {
      const yanit = await page.request.get(`${job(e)}/indexing/consoleText`);
      log = yanit.ok() ? await yanit.text() : '';
      if (/Finished: /.test(log)) break;
      await page.waitForTimeout(2000);
    }
    if (!/Finished: SUCCESS/.test(log)) throw new Error(`branch taramasi basarili bitmedi: ${log.split('\n').slice(-3).join(' | ')}`);
    for (const satir of log.split('\n').filter((x) => /Checking branch|found|Met criteria|Scheduled build|Finished:/.test(x))) {
      console.log(`    ${satir.trim()}`);
    }
    await page.goto(`${job(e)}/`);
    await page.waitForLoadState('networkidle').catch(() => {});
    await goruntu(page, ad);
  },

  async olustur(page, e, isim, ad) {
    await page.goto(`${klasor(e)}/newJob`);
    await page.locator('#name').fill(isim);
    await page.locator('input[name="mode"][value="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject"]').check({ force: true });
    await goruntu(page, `${ad}-yeni`);
    await page.locator('#ok-button').click();
    await page.waitForURL(/\/configure$/);
    await page.getByRole('button', { name: 'Add source' }).click();
    await page.locator('.jenkins-dropdown, .tippy-box').getByText('Git', { exact: true }).first().click();
    const depo = page.locator('input[name="_.remote"]');
    await depo.fill(`${GITLAB_URL}/${e.proje}.git`);
    await depo.blur();
    const kimlik = page.locator('select[name="_.credentialsId"]').first();
    await expect(kimlik.locator('option[value="gitlab-repo"]')).toHaveCount(1);
    await kimlik.selectOption('gitlab-repo');
    await page.waitForTimeout(1500);
    await depo.scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-kaynak`);
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await kaydedildi(page, `${job(e)}/`);
    tamam(`Multibranch Pipeline olusturuldu: ekip-${e.no}/${isim}`);
  },

  // Job > Configure > Branch Sources: "Discover tags" davranisi ve build stratejileri
  // (Regular branches + Tags). Tag'ler kesfedilir ve yeni tag'in build'i kendiliginden baslar.
  async 'tag-kesfi'(browser, nn, ad) {
    const e = ekip(nn);
    const page = await jenkinsGiris(browser, nn);
    await page.goto(`${job(e)}/configure`);
    await page.waitForLoadState('networkidle').catch(() => {});
    // Eklenmis ogeler descriptorid ozniteligiyle bulunur (basliktaki metin yardim dugmesini de icerir).
    const oge = (sinif) => page.locator(`[descriptorid="${sinif}"]`);
    const TAG_KESFI = 'jenkins.plugins.git.traits.TagDiscoveryTrait';
    const DAL = 'jenkins.branch.buildstrategies.basic.BranchBuildStrategyImpl';
    const TAG = 'jenkins.branch.buildstrategies.basic.TagBuildStrategyImpl';
    const ekle = page.getByRole('button', { name: 'Add', exact: true });
    const menudenSec = async (dugme, metin, sinif) => {
      if (await oge(sinif).count()) return false;
      await dugme.click();
      await page.locator('.jenkins-dropdown, .tippy-box').last().getByText(metin, { exact: true }).click();
      await expect(oge(sinif).first()).toBeAttached();
      return true;
    };
    // Davranislar (Behaviors) "Add" dugmesi 2., build stratejileri "Add" dugmesi 3. siradadir
    // (1. dugme credential ekler).
    const eklenen = [];
    if (await menudenSec(ekle.nth(1), 'Discover tags', TAG_KESFI)) eklenen.push('Discover tags');
    if (await menudenSec(ekle.nth(2), 'Regular branches', DAL)) eklenen.push('Regular branches');
    if (await menudenSec(ekle.nth(2), 'Tags', TAG)) eklenen.push('Tags');
    // Tags: yalnizca son 1 gun icinde olusturulan tag'ler kendiliginden build edilir
    const azami = page.locator('input[name="_.atMostDays"]');
    await azami.fill('1');
    await azami.scrollIntoViewIfNeeded();
    await goruntu(page, ad);
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await kaydedildi(page, `${job(e)}/`);
    // Kalici mi? Ayar sayfasi yeniden acilip denetlenir.
    await page.goto(`${job(e)}/configure`);
    await page.waitForLoadState('networkidle').catch(() => {});
    await expect(oge(TAG_KESFI)).toHaveCount(1);
    await expect(oge(DAL)).toHaveCount(1);
    await expect(oge(TAG)).toHaveCount(1);
    await expect(azami).toHaveValue('1');
    tamam(`tag kesfi ve build stratejileri kayitli (Discover tags; Regular branches; Tags: en cok 1 gunluk)${eklenen.length ? `; eklenen: ${eklenen.join(', ')}` : '; zaten vardi'}`);
  },

  // Job (branch ya da tag) sayfasinda "Build Now": ornegin rollback provasindan sonra v1.1.0'i yeniden deploy etmek
  async 'build-baslat'(browser, nn, dal, ad) {
    const e = ekip(nn);
    const page = await jenkinsGiris(browser, nn);
    await page.goto(`${job(e)}/job/${encodeURIComponent(encodeURIComponent(dal))}/`);
    await page.waitForLoadState('networkidle').catch(() => {});
    const adres = `${job(e)}/job/${encodeURIComponent(encodeURIComponent(dal))}`;
    const son = async () => {
      const y = await page.request.get(`${adres}/lastBuild/api/json?tree=number,building,result`);
      return y.ok() ? y.json() : { number: 0, building: false, result: null };
    };
    const once = (await son()).number;
    const dugme = page.getByRole('link', { name: /^Build Now$/ }).or(page.getByRole('button', { name: /^Build Now$/ })).first();
    await dugme.scrollIntoViewIfNeeded();
    await goruntu(page, ad);
    await dugme.click();
    // Yeni build'in bitmesini bekler (en cok 15 dk).
    let b = { number: once, building: true };
    for (let i = 0; i < 180 && (b.number <= once || b.building); i += 1) {
      await page.waitForTimeout(5000);
      b = await son();
    }
    if (b.number <= once || b.building) throw new Error(`${dal}: yeni build bitmedi`);
    if (b.result !== 'SUCCESS') throw new Error(`${dal} #${b.number}: ${b.result}`);
    tamam(`${dal}: Build Now -> #${b.number} ${b.result}`);
  },

  // Bir Jenkins sayfasini acar, beklenen metinleri denetler, goruntu alir.
  //   yol: job'a gore (ornegin /job/develop/lastBuild/); '=' ile baslarsa klasore gore
  async sayfa(browser, nn, yol, beklenen, ad) {
    const e = ekip(nn);
    const page = await jenkinsGiris(browser, nn);
    await page.goto(yol.startsWith('=') ? `${klasor(e)}${yol.slice(1)}` : `${job(e)}${yol}`);
    await page.waitForLoadState('networkidle').catch(() => {});
    for (const metin of beklenen.split('|').filter(Boolean)) {
      await expect(page.getByText(metin).locator('visible=true').first()).toBeVisible();
      tamam(`gorunuyor: ${metin}`);
    }
    await goruntu(page, ad);
  },
};
calistir(komutlar);
