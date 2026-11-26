// GitLab arayuz adimlari (Playwright). Her komut ogrenci rehberindeki bir arayuz adimidir.
//   node gitlab.cjs <komut> <ekip> [arguman ...]
// rol: lead | dev  (ekipNN-lead / ekipNN-dev hesabiyla giris yapilir)
const fs = require('fs');
const { expect } = require('playwright/test');
const { GITLAB_URL, ekip, giris, goruntu, tamam, calistir } = require('./lib.cjs');

const hesap = (e, rol) => (rol === 'lead' ? e.lead : e.dev);
const kod = (s) => encodeURIComponent(s);

// MR'i kaynak branch'ine gore bulur ve acar (acik ya da merge edilmis).
async function mrAc(page, e, kaynak, hedef) {
  const filtre = hedef ? `&target_branch=${kod(hedef)}` : '';
  await page.goto(`${e.projeUrl}/-/merge_requests?scope=all&state=all&source_branch=${kod(kaynak)}${filtre}`);
  await page.waitForLoadState('networkidle');
  const adresler = await page.locator('#content-body a[href*="/-/merge_requests/"]')
    .evaluateAll((a) => a.map((x) => x.href).filter((h) => /\/-\/merge_requests\/\d+$/.test(h)));
  if (!adresler.length) throw new Error(`MR bulunamadi: kaynak branch ${kaynak}`);
  await page.goto(adresler[0]);
  return Number(page.url().match(/merge_requests\/(\d+)/)[1]);
}

const komutlar = {
  // Profil > SSH Keys: acik anahtar ANAHTAR ortam degiskeninden gelir.
  async 'ssh-anahtari'(browser, nn, rol) {
    const e = ekip(nn);
    const anahtar = process.env.ANAHTAR;
    if (!anahtar) throw new Error('ANAHTAR tanimli degil');
    const page = await giris(browser, hesap(e, rol));
    await page.goto(`${GITLAB_URL}/-/user_settings/ssh_keys`);
    if (await page.getByText(anahtar.split(' ')[2] || '---', { exact: false }).count()) {
      tamam(`${hesap(e, rol)}: anahtar zaten kayitli`);
      return;
    }
    await page.getByTestId('crud-action-toggle').click();
    await page.getByTestId('key-public-key-field').fill(anahtar);
    await page.getByTestId('key-title-field').fill('egitim makinesi');
    await goruntu(page, `lab-02-a-ssh-anahtari-${rol}`);
    await page.getByRole('button', { name: 'Add key' }).click();
    await expect(page.getByText('egitim makinesi').first()).toBeVisible();
    tamam(`${hesap(e, rol)}: SSH anahtari profile eklendi`);
  },

  // Ekip grubunda bos proje (README'siz, private).
  async 'proje-olustur'(browser, nn) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${GITLAB_URL}/${e.grup}`);
    await page.getByTestId('new-project-button').click();
    await page.getByRole('link', { name: 'Create blank project' }).click();
    const g = (id) => page.locator(`[data-testid="${id}"]:visible`);
    await g('project-name').click();
    await g('project-name').pressSequentially('saha-ekipman-portal');
    await expect(g('project-path')).toHaveValue('saha-ekipman-portal');
    await g('initialize-with-readme-checkbox').uncheck({ force: true });
    await expect(page.locator('#project_visibility_level_0:visible')).toBeChecked();
    await goruntu(page, 'lab-02-a-proje-olustur');
    await g('project-create-button').click();
    await page.waitForURL(`${e.projeUrl}`);
    await expect(page.getByText('The repository for this project is empty')).toBeVisible();
    tamam(`proje olusturuldu: ${e.proje} (bos, private)`);
    await goruntu(page, 'lab-02-a-bos-proje');
  },

  // Settings > Repository > Branch defaults: varsayilan branch
  async 'varsayilan-branch'(browser, nn, branch) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/repository`);
    const bolum = page.locator('#branch-defaults-settings');
    await bolum.getByRole('button', { name: 'Expand' }).click();
    await bolum.getByTestId('base-dropdown-toggle').click();
    await bolum.getByRole('option', { name: branch, exact: true }).click();
    await goruntu(page, 'lab-02-a-varsayilan-branch');
    await bolum.getByRole('button', { name: 'Save changes' }).click();
    await page.waitForLoadState('networkidle');
    await page.goto(`${e.projeUrl}/-/branches`);
    await expect(page.locator('li').filter({ hasText: branch }).filter({ hasText: 'default' }).first()).toBeVisible();
    tamam(`varsayilan branch: ${branch}`);
  },

  // Settings > Repository > Protected branches: push "No one", merge "Maintainers"
  async 'branch-koru'(browser, nn, ...branchler) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/repository`);
    const bolum = page.locator('#js-protected-branches-settings');
    await bolum.getByRole('button', { name: 'Expand' }).click();
    const sec = async (dugme, secenek) => {
      await dugme.click();
      await page.locator('.dropdown-menu.show').getByText(secenek, { exact: true }).click();
      await page.keyboard.press('Escape');
    };
    for (const branch of branchler) {
      const satir = bolum.locator('tbody tr').filter({ has: page.locator('td', { hasText: new RegExp(`^\\s*${branch}(\\s|$)`) }) }).first();
      if (await satir.count()) {
        // Zaten korumali (GitLab ilk push'ta varsayilan branch'i korur): push iznini degistir
        const dugmeler = satir.locator('td button.dropdown-toggle');
        if (!(await dugmeler.nth(1).innerText()).includes('No one')) {
          await sec(dugmeler.nth(1), 'No one');
          await page.waitForLoadState('networkidle');
        }
      } else {
        await page.getByTestId('add-protected-branch-button').click();
        await bolum.getByTestId('protected-branch-dropdown').click();
        await page.locator('.dropdown-menu.show').getByText(branch, { exact: true }).click();
        const form = bolum.locator('form').filter({ has: page.getByTestId('protect-button') });
        await sec(form.locator('button.dropdown-toggle').nth(0), 'Maintainers');
        await sec(form.locator('button.dropdown-toggle').nth(1), 'No one');
        await goruntu(page, `lab-02-a-koruma-form-${branch}`);
        await page.getByTestId('protect-button').click();
        await page.waitForLoadState('networkidle');
      }
    }
    await page.reload();
    await bolum.getByRole('button', { name: 'Expand' }).click().catch(() => {});
    for (const branch of branchler) {
      const satir = bolum.locator('tbody tr').filter({ has: page.locator('td', { hasText: new RegExp(`^\\s*${branch}(\\s|$)`) }) }).first();
      await expect(satir).toContainText('Maintainers');
      await expect(satir).toContainText('No one');
      tamam(`${branch} korumali: merge Maintainers, push No one`);
    }
    await bolum.scrollIntoViewIfNeeded();
    await goruntu(page, 'lab-02-a-korumali-branchler');
  },

  // Settings > Merge requests: merge yontemi ve "All threads must be resolved"
  async 'mr-ayarlari'(browser, nn) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/merge_requests`);
    await expect(page.locator('#project_merge_method_merge')).toBeChecked();
    await expect(page.locator('#project_project_setting_attributes_squash_option_default_off')).toBeChecked();
    const kutu = page.locator('#project_only_allow_merge_if_all_discussions_are_resolved');
    await kutu.check({ force: true });
    await kutu.scrollIntoViewIfNeeded();
    await goruntu(page, 'lab-02-a-mr-ayarlari');
    await page.getByTestId('save-merge-request-changes-button').click();
    await page.waitForLoadState('networkidle');
    await page.reload();
    await expect(kutu).toBeChecked();
    tamam('MR ayarlari: Merge commit; cozulmemis thread varken merge kapali');
  },

  // Plan > Issues > New issue
  async 'issue-ac'(browser, nn, rol, baslik, aciklama, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    await page.goto(`${e.projeUrl}/-/issues/new`);
    await page.getByTestId('work-item-title-input').fill(baslik);
    const editor = page.locator('#content-body [contenteditable="true"]').first();
    await editor.click();
    await page.keyboard.type(aciklama);
    await goruntu(page, `${ad}-form`);
    await page.getByRole('button', { name: 'Create issue' }).click();
    await page.waitForURL(/\/-\/(issues|work_items)\/\d+/);
    const iid = page.url().match(/\/(\d+)(?:[?#].*)?$/)[1];
    await expect(page.getByRole('heading', { name: baslik }).first()).toBeVisible();
    tamam(`issue #${iid} acildi: ${baslik}`);
    await goruntu(page, ad);
  },

  // Yeni MR: sablon kendiliginden gelir; aciklama doldurulur.
  //   mr-ac <nn> <rol> <kaynak> <hedef> <baslik> <closes-iid|-> <squash:evet|hayir> <sil:evet|hayir> <goruntu-adi>
  // Aciklama metni ACIKLAMA ortam degiskeninden gelir (iki bolum "|" ile ayrilir: ne/neden | nasil test edildi).
  async 'mr-ac'(browser, nn, rol, kaynak, hedef, baslik, closes, squash, sil, ad) {
    const e = ekip(nn);
    const [ne, nasil] = (process.env.ACIKLAMA || '|').split('|');
    const page = await giris(browser, hesap(e, rol));
    await page.goto(`${e.projeUrl}/-/merge_requests/new?merge_request[source_branch]=${kod(kaynak)}&merge_request[target_branch]=${kod(hedef)}`);
    await page.getByTestId('issuable-form-title-field').fill(baslik);
    await expect(page.getByTestId('content-editor')).toContainText('Nasıl test edildi?');
    tamam('MR sablonu kendiliginden geldi (.gitlab/merge_request_templates/Default.md)');
    await goruntu(page, `${ad}-sablon`);
    // Sablonun sonundaki "Closes #" issue onerisi acar; oneri kutusu kapatilir.
    await page.getByTestId('issuable-form-title-field').click();
    await page.keyboard.press('Escape');
    await page.getByTestId('editing-mode-switcher').click({ force: true });
    const alan = page.locator('#merge_request_description');
    await expect(alan).toBeVisible();
    const kapanis = closes === '-' ? '' : `\n\nCloses #${closes}`;
    await alan.fill(`## Ne değişti, neden?\n\n${ne.trim()}\n\n## Nasıl test edildi?\n\n${nasil.trim()}\n\n- [x] Unit testler eklendi ya da güncellendi${kapanis}\n`);
    // Reviewer: ekibin diger uyesi
    const diger = rol === 'dev' ? e.lead : e.dev;
    try {
      await page.locator('.js-reviewer-search').click({ timeout: 5000 });
      await page.locator('.dropdown-menu.show, .dropdown-menu-reviewer').getByText(`@${diger}`).first().click({ timeout: 5000 });
      await page.keyboard.press('Escape');
      tamam(`reviewer: ${diger}`);
    } catch (_) {
      console.log(`  bilgi  reviewer alani otomasyonla secilemedi; MR reviewer atanmadan acilir`);
      await page.keyboard.press('Escape');
    }
    const kutu = async (id, deger) => {
      const k = page.locator(id);
      if (await k.count()) { if (deger === 'evet') await k.check({ force: true }); else await k.uncheck({ force: true }); }
    };
    await kutu('#merge_request_force_remove_source_branch', sil);
    await kutu('#merge_request_squash', squash);
    await page.getByRole('button', { name: 'Create merge request' }).scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-form`);
    await page.getByRole('button', { name: 'Create merge request' }).click();
    await page.waitForURL(/\/-\/merge_requests\/\d+$/);
    const iid = page.url().match(/(\d+)$/)[1];
    await expect(page.getByTestId('title-content')).toContainText(baslik);
    tamam(`MR !${iid} acildi: ${kaynak} -> ${hedef} (squash: ${squash}, kaynak branch silinsin: ${sil})`);
    await page.waitForLoadState('networkidle');
    await goruntu(page, ad);
  },

  // Reviewer: Changes sekmesinde bir satira yorum (thread) yazar.
  async 'mr-yorum'(browser, nn, rol, kaynak, dosya, metin, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak);
    await page.goto(`${e.projeUrl}/-/merge_requests/${iid}/diffs`);
    // Diff bilesenleri yuklenmeden satir dugmeleri calismaz.
    await page.waitForLoadState('networkidle');
    await page.locator('diff-file-mounted').first().waitFor({ state: 'attached' });
    const kutu = page.locator('article.rd-diff-file').filter({ hasText: dosya }).first();
    const satir = kutu.locator('tr[data-testid="hunk-lines-inline"]')
      .filter({ has: page.locator('td.rd-line-content[data-change="added"]') }).first();
    await satir.scrollIntoViewIfNeeded();
    // Yorum dugmesi satirin uzerine gelince belirir.
    await satir.locator('td.rd-line-content').hover();
    await page.waitForTimeout(500);
    await satir.getByTestId('new_discussion_toggle').click();
    const editor = kutu.locator('.ProseMirror').locator('visible=true').first();
    await editor.click();
    await page.keyboard.type(metin);
    await goruntu(page, `${ad}-yaziliyor`);
    await kutu.getByTestId('reply-comment-button').click();
    await expect(page.getByText(metin).first()).toBeVisible();
    tamam(`!${iid}: ${hesap(e, rol)} ${dosya} dosyasinda bir satira yorum yazdi (thread acik)`);
    await goruntu(page, ad);
  },

  // Merge engelini gosterir: dugme yok ya da pasif; beklenen metin sayfada.
  async 'mr-engel'(browser, nn, rol, kaynak, beklenen, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak);
    const widget = page.locator('.mr-state-widget, [data-testid="widget-state"], .mr-widget-section').first();
    await expect(page.getByText(new RegExp(beklenen, 'i')).first()).toBeVisible();
    // "Merge" dugmesi ya hic yoktur (yetki yok) ya da yerinde "Set to auto-merge" vardir (engel var).
    const merge = page.getByRole('button', { name: 'Merge', exact: true });
    const var_ = await merge.count();
    if (var_ && await merge.first().isEnabled()) throw new Error('Merge dugmesi etkin; engel bekleniyordu');
    tamam(`!${iid}: ${hesap(e, rol)} merge edemiyor: "${beklenen}"`);
    await widget.scrollIntoViewIfNeeded().catch(() => {});
    await goruntu(page, ad);
  },

  // Yazar: acik thread'leri cozer.
  async 'mr-thread-coz'(browser, nn, rol, kaynak, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak);
    await page.waitForLoadState('networkidle');
    let sayi = 0;
    for (;;) {
      const dugme = page.getByTestId('resolve-discussion-button').locator('visible=true').first();
      if (!(await dugme.count())) break;
      if (!/Resolve thread/.test(await dugme.innerText())) break;
      await dugme.scrollIntoViewIfNeeded();
      await dugme.click();
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);
      sayi += 1;
      if (sayi > 10) throw new Error('thread cozme dongusu bitmedi');
    }
    if (!sayi) throw new Error('cozulecek thread bulunamadi');
    await expect(page.getByText('Open threads must be resolved')).toHaveCount(0);
    tamam(`!${iid}: ${hesap(e, rol)} ${sayi} thread'i cozdu`);
    await goruntu(page, ad);
  },

  // Merge: squash secenegi MR'da ne ise o kullanilir.
  async 'mr-merge'(browser, nn, rol, kaynak, ad, hedef) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak, hedef);
    const merge = page.getByTestId('merge-button');
    await expect(merge).toBeEnabled({ timeout: 60000 });
    await expect(merge).toHaveText(/^\s*Merge\s*$/);
    await merge.scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-oncesi`);
    await merge.click();
    await expect(page.getByText(/Merged by/).first()).toBeVisible({ timeout: 60000 });
    tamam(`!${iid}: ${hesap(e, rol)} merge etti`);
    await page.waitForLoadState('networkidle');
    await goruntu(page, ad);
  },

  // Bir sayfanin goruntusu (issue, tag listesi, MR listesi, registry ...)
  async 'sayfa'(browser, nn, rol, yol, beklenen, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    await page.goto(`${e.projeUrl}${yol}`);
    for (const metin of beklenen.split('|').filter(Boolean)) {
      await expect(page.getByText(metin).locator('visible=true').first()).toBeVisible();
      tamam(`gorunuyor: ${metin}`);
    }
    await page.waitForLoadState('networkidle');
    await goruntu(page, ad);
  },

  // Reviewer: MR'i onaylar (Free katmaninda onay istege baglidir; merge'u engellemez).
  async 'mr-onayla'(browser, nn, rol, kaynak, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak);
    await page.getByTestId('approve-button').click();
    await expect(page.getByText(/Approved by/).locator('visible=true').first()).toBeVisible();
    tamam(`!${iid}: ${hesap(e, rol)} onayladi`);
    await goruntu(page, ad);
  },

  // Settings > Repository > Protected tags: v* etiketini yalnizca Maintainer olusturur
  async 'tag-koru'(browser, nn, desen) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/repository`);
    const bolum = page.locator('#js-protected-tags-settings');
    await bolum.getByRole('button', { name: 'Expand' }).click();
    await bolum.getByRole('button', { name: 'Add tag' }).click();
    await bolum.getByTestId('tags-dropdown').click();
    const menu = page.locator('.dropdown-menu.show');
    await menu.locator('input').first().fill(desen);
    await menu.getByText(/Create wildcard/).click();
    await bolum.locator('form').filter({ has: page.getByTestId('protect-tag-button') }).locator('button.dropdown-toggle').last().click();
    await page.locator('.dropdown-menu.show').getByText('Maintainers', { exact: true }).click();
    await page.keyboard.press('Escape');
    await bolum.scrollIntoViewIfNeeded();
    await goruntu(page, 'lab-02-b-korumali-tag-form');
    await page.getByTestId('protect-tag-button').click();
    await page.waitForLoadState('networkidle');
    await page.reload();
    await bolum.getByRole('button', { name: 'Expand' }).click().catch(() => {});
    const satir = page.locator('#protected-tags tbody tr, #protected-tags li').filter({ hasText: desen }).first();
    await expect(satir).toContainText('Maintainers');
    tamam(`korumali tag: ${desen} (olusturabilen: Maintainers)`);
    await page.locator('#protected-tags').scrollIntoViewIfNeeded();
    await goruntu(page, 'lab-02-b-korumali-tag');
  },

  // Settings > Repository > Deploy tokens. Token degeri ekrana yazilmaz; yalnizca
  // /lab/cikti/token-<ad> dosyasina (lab-ortami/.cache/ui, repoya girmez) kaydedilir.
  async 'deploy-token'(browser, nn, ad, kapsamlar, goruntuAdi) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/repository`);
    const bolum = page.locator('#js-deploy-tokens');
    await bolum.getByRole('button', { name: 'Expand' }).click();
    await bolum.getByRole('button', { name: 'Add token' }).click();
    await bolum.locator('#deploy_token_name').fill(ad);
    await bolum.locator('#deploy_token_username').fill(ad);
    for (const k of kapsamlar.split(',')) await bolum.locator(`#deploy_token_${k}`).check({ force: true });
    await bolum.getByRole('button', { name: 'Create deploy token' }).scrollIntoViewIfNeeded();
    await goruntu(page, `${goruntuAdi}-form`);
    await bolum.getByRole('button', { name: 'Create deploy token' }).click();
    await expect(page.getByText(/deploy token has been created/i).first()).toBeVisible();
    const alanlar = bolum.locator('input[readonly]:visible, input[type="text"][readonly]');
    const degerler = await alanlar.evaluateAll((a) => a.map((x) => x.value).filter(Boolean));
    const token = degerler.find((d) => d !== ad && d.length >= 20);
    if (!token) throw new Error('token degeri sayfada bulunamadi');
    fs.writeFileSync(`/lab/cikti/token-${ad}`, token, { mode: 0o600 });
    tamam(`deploy token olusturuldu: ${ad} (${kapsamlar}); deger yalnizca bir kez gosterilir`);
    // Goruntude token degeri maskelenir.
    await goruntu(page, goruntuAdi, { mask: [alanlar] });
  },

  // Settings > Access tokens: Project Access Token (rol ve scope ile). Deger ekrana yazilmaz;
  // yalnizca /lab/cikti/token-<dosya> dosyasina kaydedilir.
  async 'access-token'(browser, nn, isim, rol, kapsam, dosya, ad) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/access_tokens`);
    await page.getByRole('button', { name: 'Add new token' }).click();
    await page.getByTestId('access-token-name-field').fill(isim);
    await page.locator('#resource_access_token_access_level').selectOption({ label: rol });
    await page.getByTestId(`${kapsam}-checkbox`).check({ force: true });
    await page.getByTestId('create-token-button').scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-form`);
    await page.getByTestId('create-token-button').click();
    await expect(page.getByText(/Your new project access token/i).first()).toBeVisible();
    const alanlar = page.locator('input[readonly], input[data-testid="created-access-token-field"], #new-access-token');
    const degerler = await alanlar.evaluateAll((a) => a.map((x) => x.value).filter(Boolean));
    const token = degerler.find((d) => /^glpat-/.test(d));
    if (!token) throw new Error('token degeri sayfada bulunamadi');
    fs.writeFileSync(`/lab/cikti/token-${dosya}`, token, { mode: 0o600 });
    tamam(`Project Access Token olusturuldu: ${isim} (rol ${rol}, scope ${kapsam}); deger yalnizca bir kez gosterilir`);
    await goruntu(page, ad, { mask: [alanlar] });
  },

  // Settings > Webhooks: Jenkins Multibranch job adresi, yalnizca Push events; ardindan Test > Push events
  async 'webhook'(browser, nn, adres, ad) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/hooks`);
    if (await page.getByText(adres, { exact: true }).count()) {
      tamam(`webhook zaten var: ${adres}`);
    } else {
      await komutlar.webhookEkle(page, adres, ad);
    }
    // Test > Push events
    await page.getByRole('button', { name: 'Test' }).first().click();
    await page.getByRole('button', { name: 'Push events' }).or(page.getByRole('menuitem', { name: 'Push events' })).or(page.getByRole('link', { name: 'Push events' })).first().click();
    await expect(page.getByText(/Hook executed successfully: HTTP 200/).first()).toBeVisible();
    tamam('Test > Push events: Hook executed successfully: HTTP 200');
    await goruntu(page, ad);
  },

  async webhookEkle(page, adres, ad) {
    await page.getByRole('button', { name: 'Add new webhook' }).click();
    await page.getByTestId('webhook-url').fill(adres);
    const push = page.getByRole('checkbox', { name: /^Push events/ });
    await push.check({ force: true });
    await expect(page.locator('#webhooks-mergeRequestsEvents')).not.toBeChecked();
    await expect(page.locator('#hook_enable_ssl_verification')).toBeChecked();
    await push.scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-form`);
    await page.getByRole('button', { name: 'Add webhook' }).scrollIntoViewIfNeeded();
    await goruntu(page, `${ad}-form-ssl`);
    await page.getByRole('button', { name: 'Add webhook' }).click();
    await expect(page.getByText(/Webhook (was )?created/i).first()).toBeVisible();
    await expect(page.getByText(adres, { exact: true }).first()).toBeVisible();
    tamam(`webhook eklendi: ${adres} (Push events; SSL verification acik)`);
    await goruntu(page, `${ad}-liste`);
  },

  // Settings > Webhooks > Edit: Tag push events (LAB 05-B; tag build'i icin)
  async 'webhook-tag'(browser, nn, adres, ad) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/hooks`);
    // Projede Jenkins'e giden tek webhook vardir; duzenleme baglantisi .../-/hooks/<id>/edit
    await expect(page.getByText(adres).first()).toBeVisible();
    await page.locator('a[href*="/-/hooks/"][href$="/edit"]').first().click();
    await page.waitForURL(/\/-\/hooks\/\d+\/edit/);
    // Kutu sayfanin altinda yapiskan "Save changes" cubugunun arkasinda kalir; zorla tiklama
    // Vue'nun degisiklik olayini tetiklemez. Odaklanip bosluk tusuyla isaretlenir.
    const kutu = page.getByRole('checkbox', { name: /^Tag push events/ });
    if (!(await kutu.isChecked())) {
      await kutu.focus();
      await page.keyboard.press('Space');
    }
    await expect(kutu).toBeChecked();
    await expect(page.getByRole('checkbox', { name: /^Push events/ })).toBeChecked();
    await kutu.scrollIntoViewIfNeeded();
    await goruntu(page, ad);
    await page.getByRole('button', { name: 'Save changes' }).click();
    await expect(page.getByText(/Hook (was )?(successfully )?updated|Webhook (was )?updated/i).first()).toBeVisible();
    await page.goto(`${e.projeUrl}/-/hooks`);
    await expect(page.getByText('Tag push events').locator('visible=true').first()).toBeVisible();
    tamam(`webhook ${adres}: Push events + Tag push events`);
    await goruntu(page, `${ad}-liste`);
  },

  // Settings > Merge requests > Merge checks: Pipelines must succeed
  async 'pipeline-zorunlu'(browser, nn, ad) {
    const e = ekip(nn);
    const page = await giris(browser, e.lead);
    await page.goto(`${e.projeUrl}/-/settings/merge_requests`);
    const kutu = page.locator('#project_only_allow_merge_if_pipeline_succeeds');
    await kutu.check({ force: true });
    await kutu.scrollIntoViewIfNeeded();
    await goruntu(page, ad);
    await page.getByTestId('save-merge-request-changes-button').click();
    await page.waitForLoadState('networkidle');
    await page.reload();
    await expect(kutu).toBeChecked();
    tamam('MR ayari: Pipelines must succeed acik');
  },

  // MR sayfasi: beklenen metinler (pipeline durumu, merge engeli ...) gorunene kadar bekler.
  async 'mr-durum'(browser, nn, rol, kaynak, beklenen, ad) {
    const e = ekip(nn);
    const page = await giris(browser, hesap(e, rol));
    const iid = await mrAc(page, e, kaynak);
    for (const metin of beklenen.split('|').filter(Boolean)) {
      // Durum satiri birkac ogeye bolunmustur (metin, baglanti, metin): sayfa metninde aranir.
      await expect(page.locator('#content-body')).toContainText(new RegExp(metin.replace(/ /g, '\\s+'), 'i'), { timeout: 60000 });
      tamam(`!${iid}: gorunuyor: ${metin}`);
    }
    await page.waitForLoadState('networkidle');
    await goruntu(page, ad);
  },

  // Deploy > Container Registry: uc imaj ve etiketleri
  async 'registry'(browser, nn, ad, ...etiketler) {
    const e = ekip(nn);
    const page = await giris(browser, e.dev);
    await page.goto(`${e.projeUrl}/container_registry`);
    for (const imaj of ['order-service', 'product-service', 'web-ui']) {
      await expect(page.getByRole('link', { name: new RegExp(`${imaj}$`) }).first()).toBeVisible();
    }
    tamam('Container Registry: order-service, product-service, web-ui');
    await page.waitForLoadState('networkidle');
    await goruntu(page, ad);
    await page.getByRole('link', { name: /order-service$/ }).first().click();
    for (const etiket of etiketler) {
      await expect(page.getByText(etiket, { exact: true }).first()).toBeVisible();
      tamam(`order-service etiketi: ${etiket}`);
    }
    await page.waitForLoadState('networkidle');
    await goruntu(page, `${ad}-etiketler`);
  },
};
calistir(komutlar);
