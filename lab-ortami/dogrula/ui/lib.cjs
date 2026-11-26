// Arayuz adimlarinin ortak islevleri (Playwright, Chromium).
// Tarayici lab CA'sina guvenir (imajin entrypoint'i NSS deposuna ekler); sertifika
// hatalari yok sayilmaz. Parolalar LAB_SECRET'ten turetilir, ekrana ve dosyaya yazilmaz.
const crypto = require('crypto');
const path = require('path');
const { chromium } = require('playwright');

const D = process.env.LAB_DOMAIN;
if (!D) throw new Error('LAB_DOMAIN tanimli degil');
const GITLAB_URL = `https://gitlab.${D}`;
const JENKINS_URL = `https://jenkins.${D}`;
const SONAR_URL = `https://sonar.${D}`;
const IMG_DIR = process.env.LAB_IMG_DIR || '/lab/img';

function parola(kullanici) {
  const gizli = process.env.LAB_SECRET;
  if (!gizli) throw new Error('LAB_SECRET tanimli degil');
  return crypto.createHmac('sha256', gizli).update(kullanici).digest('base64')
    .replace(/[/+=]/g, '').slice(0, 16);
}

function ekip(nn) {
  const no = String(nn).padStart(2, '0');
  return {
    no,
    lead: `ekip${no}-lead`,
    dev: `ekip${no}-dev`,
    grup: `egitim/ekip-${no}`,
    proje: `egitim/ekip-${no}/saha-ekipman-portal`,
    projeUrl: `${GITLAB_URL}/egitim/ekip-${no}/saha-ekipman-portal`,
  };
}

async function baslat() {
  return chromium.launch({ headless: true });
}

async function sayfa(browser) {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    locale: 'en-US',
    timezoneId: 'Europe/Istanbul',
  });
  context.setDefaultTimeout(30000);
  const page = await context.newPage();
  return page;
}

// GitLab'e kullanici adi ve parolayla giris yapar.
async function giris(browser, kullanici) {
  const page = await sayfa(browser);
  await page.goto(`${GITLAB_URL}/users/sign_in`);
  await page.getByTestId('username-field').fill(kullanici);
  await page.getByTestId('password-field').fill(parola(kullanici));
  await page.getByTestId('sign-in-button').click();
  await page.waitForURL((url) => !url.pathname.startsWith('/users/sign_in'));
  return page;
}

// Jenkins'e ekip kullanicisiyla (ekipNN) giris yapar.
async function jenkinsGiris(browser, nn) {
  const e = ekip(nn);
  const page = await sayfa(browser);
  await page.goto(`${JENKINS_URL}/login`);
  await page.locator('input[name="j_username"]').fill(`ekip${e.no}`);
  await page.locator('input[name="j_password"]').fill(parola(`jenkins:ekip${e.no}`));
  await page.locator('button[name="Submit"], button[type="submit"]').first().click();
  await page.waitForURL((url) => !url.pathname.startsWith('/login'));
  return page;
}

// SonarQube'a ekip kullanicisiyla (ekipNN) giris yapar.
async function sonarGiris(browser, nn) {
  const e = ekip(nn);
  const page = await sayfa(browser);
  await page.goto(`${SONAR_URL}/sessions/new`);
  await page.locator('#login-input, input[name="login"]').first().fill(`ekip${e.no}`);
  await page.locator('#password-input, input[name="password"]').first().fill(`${parola(`sonar-ekip${e.no}`)}#Sq7`);
  await page.getByRole('button', { name: /log in/i }).click();
  await page.waitForURL((url) => !url.pathname.startsWith('/sessions'));
  return page;
}

// Arayuzde uretilen bir token'i okur (lab-ortami/.cache/ui/token-<ad>; repoya girmez).
function tokenOku(ad) {
  const fs = require('fs');
  const dosya = `/lab/cikti/token-${ad}`;
  if (!fs.existsSync(dosya)) throw new Error(`token dosyasi yok: .cache/ui/token-${ad}`);
  return fs.readFileSync(dosya, 'utf8').trim();
}
function tokenYaz(ad, deger) {
  require('fs').writeFileSync(`/lab/cikti/token-${ad}`, deger, { mode: 0o600 });
}

// Ekran goruntusu: lab-rehberleri/img/<ad>.png
async function goruntu(page, ad, secenek = {}) {
  const dosya = path.join(IMG_DIR, `${ad}.png`);
  await page.screenshot({ path: dosya, fullPage: false, ...secenek });
  console.log(`  goruntu: ${dosya}`);
}

function tamam(mesaj) { console.log(`  tamam  ${mesaj}`); }

// komutlar: { ad: async (browser, ...arg) => {} }
async function calistir(komutlar) {
  const [ad, ...arg] = process.argv.slice(2);
  const komut = komutlar[ad];
  if (!komut) {
    console.error(`kullanim: node <betik>.cjs <${Object.keys(komutlar).join('|')}> [arguman ...]`);
    process.exit(2);
  }
  const browser = await baslat();
  try {
    await komut(browser, ...arg);
  } catch (hata) {
    console.error(`HATA   ${ad}: ${String(hata.message || hata).split('\n').slice(0, 6).join('\n       ')}`);
    try {
      const sayfalar = browser.contexts().flatMap((c) => c.pages());
      // Kimlik bilgisi formlarinda hata aninda maskeleme henuz calismamis olabilir.
      // Bu adimlarda hata ekran goruntusu almak sir sizdirabilir.
      if (sayfalar.length && !/anahtar|credential|token/.test(ad)) {
        const dosya = `/lab/cikti/hata-${ad}-${Date.now()}.png`;
        await sayfalar[sayfalar.length - 1].screenshot({ path: dosya, fullPage: true });
        console.error(`       sayfa: ${sayfalar[sayfalar.length - 1].url()}`);
        console.error(`       goruntu: lab-ortami/.cache/ui/${path.basename(dosya)}`);
      }
    } catch (_) { /* goruntu alinamadi */ }
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
}

module.exports = {
  D, GITLAB_URL, JENKINS_URL, SONAR_URL, parola, ekip, baslat, sayfa, giris, jenkinsGiris, sonarGiris,
  tokenOku, tokenYaz, goruntu, tamam, calistir,
};
