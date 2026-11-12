# Yağan Dijital · Anı Kamerası — Kurulum Rehberi

Bu rehber, yazılım bilgisi olmayan biri için yazıldı. Her şey tarayıcıdan yapılır, bilgisayara program kurmanız gerekmez. Toplam süre yaklaşık 45 dakika.

**Neye ihtiyacınız var?**
- Bir e-posta adresi
- Bu klasör (`yagan-ani-kamerasi`)
- İsterseniz bir alan adı (örn. `yagandijital.com`). Başlangıçta şart değil.

**Kullanılan hizmetler**
| Hizmet | Ne işe yarar | Ücret |
|---|---|---|
| **Supabase** (supabase.com) | Veritabanı, fotoğraf depolama, panel girişleri | Ücretsiz plan teste yeter. Gerçek kullanım için Pro plan (aylık yaklaşık 25 $). Güncel fiyatı sitesinden kontrol edin. |
| **Netlify** (netlify.com) | Sitenin yayınlanması | Ücretsiz plan yeterli |

---

## 1. Supabase projesi açın

1. **supabase.com** adresine gidin, **Start your project** deyip e-postanızla kaydolun.
2. **New project** deyin:
   - **Name:** `ani-kamerasi`
   - **Database Password:** güçlü bir şifre yazın ve bir yere kaydedin.
   - **Region:** **Central EU (Frankfurt)**. Türkiye'ye en yakın bölge budur, fotoğraflar hızlı yüklenir.
3. **Create new project** deyin. Hazırlanması 1–2 dakika sürer.

## 2. Veritabanını kurun

1. Sol menüden **SQL Editor**'ı açın.
2. **New query** deyin.
3. Bu klasördeki `supabase/schema.sql` dosyasını Not Defteri ile açın. Tamamını kopyalayıp SQL Editor'a yapıştırın.
4. Sağ alttaki **Run** düğmesine basın. "Success" yazısını görmelisiniz.

Bu adım tabloları, güvenlik kurallarını, fotoğraf deposunu ve iki markayı (**Yağan Dijital** `YGN` ve **Latife** `LTF`) oluşturur.

## 3. Site ayarlarını yapın

1. Supabase'de sol alttaki **Project Settings** (dişli simgesi) → **API** bölümüne girin. Yeni arayüzde bu bilgiler üstteki **Connect** düğmesinde de görünür.
2. Buradan iki bilgiyi kopyalayın:
   - **Project URL**, örn. `https://abcdxyz.supabase.co`
   - **anon public** anahtar (yeni arayüzde adı **Publishable key**, `sb_publishable_...` ile başlar)
3. Bu klasördeki `site/config.js` dosyasını Not Defteri ile açın. İki değeri tırnakların içine yapıştırıp kaydedin.

> ⚠️ **service_role** ya da **secret** anahtarını asla bu dosyaya yazmayın. O anahtar her şeye erişir.

## 4. İlk yönetici hesabınızı oluşturun

1. Supabase'de **Authentication** → **Users** → **Add user** → **Create new user** yolunu izleyin.
   - E-postanızı ve bir şifre yazın.
   - **Auto Confirm User** kutusunu işaretleyin.
2. **SQL Editor** → **New query** açın. Aşağıdaki komutu kendi e-postanızla düzenleyip **Run** deyin:
   ```sql
   insert into public.profiles (user_id, role)
   select id, 'super' from auth.users where email = 'sizin@epostaniz.com';
   ```
3. **Önemli:** Dışarıdan kimsenin hesap açamaması için **Authentication** → **Sign In / Providers** bölümüne girin. **Allow new users to sign up** seçeneğini kapatın ve kaydedin.

Bundan sonraki kullanıcıları (Latife yöneticisi, salonlar) panelin **Kullanıcılar** sekmesinden yetkilendireceksiniz. Her kullanıcıyı önce bu adımdaki gibi **Add user** ile eklemeniz gerekir.

## 5. Siteyi yayınlayın (Netlify)

1. **app.netlify.com/drop** adresine gidin ve e-postanızla kaydolun.
2. Bu klasördeki **`site`** klasörünü sayfadaki kutuya sürükleyip bırakın.
3. Birkaç saniye içinde siteniz yayında olur. Adresi `https://rastgele-isim.netlify.app` gibi bir şey olur.
4. **Site configuration** → **Change site name** ile adı `yagan-ani` gibi bir şeye çevirin.

Dosyalarda bir değişiklik yaparsanız: **Deploys** sekmesine girin ve `site` klasörünü yeniden sürükleyin.

## 6. Deneyin

1. `https://siteniz.netlify.app/panel.html` adresine gidin ve 4. adımdaki e-posta ve şifreyle giriş yapın.
2. **Kodlar** sekmesinde marka olarak **Yağan Dijital**, paket olarak **Standart** seçin, adet 3 yazıp **Üret** deyin.
3. Ana sayfaya (`https://siteniz.netlify.app`) gidin, kodlardan birini yazın ve etkinliği oluşturun.
4. Çıkan QR kodu telefonunuzla okutun, adınızı yazın ve birkaç fotoğraf çekin.
5. **Albüm linki** ile fotoğrafların geldiğini kontrol edin.
6. Aynı denemeyi **Latife** (`LTF-...`) koduyla yapın. Sayfaların Latife rengi ve adıyla açıldığını göreceksiniz.

---

## Günlük kullanım

| Ne yapmak istiyorsunuz? | Nerede? |
|---|---|
| Salona/bayiye kod paketi hazırlamak | Panel → **Kodlar** → firma seçip üret → **Kod kartlarını yazdır** ya da **CSV indir** |
| Yeni salon/bayi eklemek | Panel → **Firmalar** |
| Salonun kendi panelini görmesi | Supabase'de kullanıcı ekleyin → Panel → **Kullanıcılar** → yetki: **Firma** |
| Latife yöneticisine panel vermek | Kullanıcı ekleyin → Panel → **Kullanıcılar** → yetki: **Marka yöneticisi**, marka: Latife |
| Masa kartı basmak | Panel → **Etkinlikler** → **Kart** |
| Süresi dolan fotoğrafları silmek (KVKK) | Panel → **Etkinlikler** → **Süresi dolanları sil**. Ayda bir yapın. |
| Logo eklemek | Logo dosyasını `site/logos/` klasörüne koyun (örn. `yagan.png`) ve siteyi yeniden yükleyin. Sonra Panel → **Markalar** → **Düzenle** → Logo adresi: `/logos/yagan.png` |

### Paketler
- **Standart:** kişi başı 24 poz, fotoğraflar 90 gün saklanır.
- **Premium:** sınırsız poz, canlı ekran, 365 gün saklama.

Paketleri değiştirmek için Supabase'de **Table Editor** → `packages` tablosunu kullanın. Örneğin yeni bir "Ekonomik" paket ekleyebilirsiniz.

## Latife'yi kendi alan adıyla yayınlamak

1. Netlify → **Domain management** → **Add a domain** ile önce `yagandijital.com`'u, sonra **Add domain alias** ile `latife.com.tr`'yi ekleyin. Netlify alan adı firmanızda hangi ayarları yapmanız gerektiğini gösterir.
2. Panel → **Markalar** → Latife → **Düzenle** → Alan adı: `latife.com.tr` yazıp kaydedin.

Artık `latife.com.tr` adresine girenler sistemi Latife görünümüyle görür. `LTF-` kodları hangi adresten girilirse girilsin Latife olarak açılır.

## Firma kendi depolamasını kullanmak isterse

Bu sürümde fotoğrafların hepsi sizin Supabase hesabınızda, etkinlik bazında ayrı klasörlerde tutulur. Firmalar sayfasındaki **Depolama: Kendi hesabı** seçeneği şimdilik sadece bir işarettir; firmayı not almak içindir. Büyük bir bayi gerçekten kendi hesabını isterse, ona ayrı bir Supabase projesi ve ayrı bir Netlify sitesi kurun. Aynı dosyalar kullanılır, sadece `config.js` farklı olur.

## Yayına almadan önce kontrol listesi

- [ ] `site/kvkk.html` içindeki [köşeli parantez] alanlarını doldurun ve metni bir avukata kontrol ettirin.
- [ ] Supabase'i **Pro** plana geçirin. Ücretsiz projeler 1 hafta kullanılmayınca durdurulur ve depolaması 1 GB ile sınırlıdır.
- [ ] Yeni kayıtları kapattığınızı kontrol edin (4. adım, madde 3).
- [ ] Kendi alan adınızı bağlayın.
- [ ] En az bir deneme etkinliğini 10–20 kişiyle gerçek ortamda deneyin.

## Kapasite hesabı (yaklaşık)

- Fotoğraflar telefonda küçültülür. Ortalama boyut yaklaşık **0,3–0,5 MB**.
- 150 kişilik bir düğün yaklaşık 1.000–1.500 fotoğraf, yani **400–700 MB** eder.
- Supabase Pro'daki 100 GB depolama, aynı anda yaklaşık **150–250 düğün** saklar. Süresi dolanları sildikçe yer açılır.
- Bir albüm en fazla 5.000 fotoğraf alır. Bu sınır `schema.sql` içinde değiştirilebilir.

## Sorun giderme

| Belirti | Çözüm |
|---|---|
| Sayfanın üstünde "Kurulum tamamlanmadı" yazıyor | `config.js` doldurulmamış (3. adım) |
| Panelde "Bu hesaba panel yetkisi verilmemiş" çıkıyor | 4. adımdaki SQL komutu çalıştırılmamış ya da e-posta yanlış yazılmış |
| Fotoğraf yüklenmiyor | Supabase → **Storage** bölümünde `photos` adlı kutunun olduğunu kontrol edin. Yoksa `schema.sql`'i yeniden çalıştırın (tekrar çalıştırmak zararsızdır). |
| Kod "bulunamadı" diyor | Kodun durumu Panel → **Kodlar**'da "Kullanılmamış" olmalı |
