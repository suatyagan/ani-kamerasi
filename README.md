# Yağan Dijital · Anı Kamerası

Düğün, nişan, kına ve benzeri etkinlikler için misafirlerin uygulama indirmeden fotoğraf çektiği ve fotoğrafların ortak albümde toplandığı sistem.

**Kurulum için:** `KURULUM.md` dosyasını okuyun.

## Klasörler
- `supabase/schema.sql` — Veritabanı: tablolar, güvenlik kuralları, işlemler. Supabase SQL Editor'da bir kez çalıştırılır.
- `site/` — Netlify'a yüklenecek site.
  - `index.html` — Aktivasyon kodunu girip etkinlik oluşturma
  - `e.html` — Misafir kamerası (QR buraya açılır)
  - `album.html` — Çiftin özel albümü: indirme, gizleme, canlı ekran
  - `card.html` — Yazdırılabilir QR masa kartı
  - `panel.html` — Yönetim paneli: kodlar, etkinlikler, firmalar, markalar, kullanıcılar
  - `kodkart.html` — Aktivasyon kodu kartlarının baskısı
  - `kvkk.html` — Aydınlatma metni (TASLAK, doldurulmalı)
  - `config.js` — Supabase bağlantı bilgileri

## Özellikler
- Aktivasyon kodu (`YGN-XXXX-XXXX`): her kod tek etkinlik açar, son kullanma tarihi vardır, hatalı denemeler sınırlanır
- Çoklu marka: kodun öneki ya da alan adı markayı belirler (Yağan Dijital, Latife, ...)
- Paketler: poz sınırı, saklama süresi, canlı ekran
- Yetkiler: tam yetki / marka yöneticisi / firma (salon-bayi)
- Misafir: ad + KVKK onayı, film efekti, kişi başı poz sayacı
- "Ertesi sabah açılsın" modu (tek kullanımlık makine hissi)
- ZIP indirme, canlı slayt ekranı, fotoğraf gizleme, yüklemeyi kapatma
- Süresi dolan etkinliklerin fotoğraflarıyla birlikte silinmesi

## Teknik
Derleme gerektirmeyen düz HTML/JS. Supabase (Postgres + Storage + Auth). Kütüphaneler CDN'den yüklenir: supabase-js 2, qrcode-generator 1.4.4, JSZip 3.10.1.
