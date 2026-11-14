// Ortak yardımcılar — tüm sayfalarda kullanılır.
(function () {
  const cfg = window.APP_CONFIG || {};
  const configured = cfg.SUPABASE_URL && !/PROJE-KODUNUZ/.test(cfg.SUPABASE_URL) && cfg.SUPABASE_ANON_KEY && !/ANON-ANAHTARINIZ/.test(cfg.SUPABASE_ANON_KEY);

  const App = (window.App = {});
  App.configured = configured;
  App.sb = configured && window.supabase ? window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY) : null;

  App.$ = (s, r = document) => r.querySelector(s);
  App.$$ = (s, r = document) => [...r.querySelectorAll(s)];
  App.qs = (k) => new URLSearchParams(location.search).get(k);
  App.esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

  const months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
  App.fmtDate = (iso) => { if (!iso) return ""; const d = new Date(String(iso).length <= 10 ? iso + "T12:00:00" : iso); return d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear(); };
  App.fmtDateTime = (iso) => { const d = new Date(iso); return App.fmtDate(iso) + " " + String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0"); };
  App.couple = (ev) => ev.name_b ? ev.name_a + " & " + ev.name_b : ev.name_a;

  // Sunucu fonksiyonu çağır; hata varsa Türkçe mesajla fırlat
  App.rpc = async (name, args) => {
    if (!App.sb) throw new Error("Site henüz ayarlanmadı (config.js).");
    const { data, error } = await App.sb.rpc(name, args || {});
    if (error) throw new Error(error.message || "Bir hata oluştu.");
    if (data && data.error) throw new Error(data.error);
    return data;
  };

  App.photoUrl = (path) => App.sb.storage.from("ak-photos").getPublicUrl(path).data.publicUrl;
  App.base = () => location.origin + location.pathname.replace(/[^/]*$/, "");
  App.guestLink = (slug) => App.base() + "e.html?s=" + encodeURIComponent(slug);
  App.albumLink = (slug, key) => App.base() + "album.html?s=" + encodeURIComponent(slug) + "&k=" + encodeURIComponent(key);
  App.cardLink = (slug) => App.base() + "card.html?s=" + encodeURIComponent(slug);

  // Marka görünümü
  App.applyBrand = (b) => {
    if (!b) return;
    App.brand = b;
    if (b.primary_color) document.documentElement.style.setProperty("--accent", b.primary_color);
    App.$$("[data-brand-name]").forEach((e) => (e.textContent = b.name));
    App.$$("[data-brand-tagline]").forEach((e) => (e.textContent = b.tagline || "Anı Kamerası"));
    App.$$("[data-brand-logo]").forEach((e) => {
      if (b.logo_url) { e.innerHTML = `<img src="${App.esc(b.logo_url)}" alt="${App.esc(b.name)}">`; }
      else { e.innerHTML = `<span class="dot"></span>`; }
    });
    const t = document.querySelector("title");
    if (t && !t.dataset.base) t.dataset.base = t.textContent;
    if (t) t.textContent = t.dataset.base + " · " + b.name;
  };
  App.loadSiteBrand = async (prefix) => {
    try { App.applyBrand(await App.rpc("ak_public_brand", { p_host: location.hostname, p_prefix: prefix || null })); } catch (e) { /* varsayılan görünüm */ }
  };

  // QR kod (qrcode-generator kütüphanesi)
  App.qrSvg = (text) => {
    if (!window.qrcode) return "";
    const q = window.qrcode(0, "M"); q.addData(text); q.make();
    return q.createSvgTag({ cellSize: 4, margin: 2, scalable: true });
  };

  // Bildirim
  let tt;
  App.toast = (m) => {
    let t = App.$("#toast");
    if (!t) { t = document.createElement("div"); t.id = "toast"; t.className = "toast"; document.body.appendChild(t); }
    t.textContent = m; t.classList.add("on"); clearTimeout(tt); tt = setTimeout(() => t.classList.remove("on"), 2600);
  };
  App.copy = async (text) => {
    try { await navigator.clipboard.writeText(text); App.toast("Kopyalandı"); }
    catch (e) { window.prompt("Kopyalayın:", text); }
  };
  App.showError = (el, msg) => { el.textContent = msg; el.classList.toggle("on", !!msg); };

  // Fotoğrafı küçült (en fazla 1600 px) ve isteğe bağlı film efekti uygula → JPEG Blob
  App.stamp = (dateIso) => { const d = new Date((dateIso || new Date().toISOString()).slice(0, 10) + "T12:00:00"); return `'${String(d.getFullYear()).slice(2)} ${String(d.getMonth() + 1).padStart(2, "0")} ${String(d.getDate()).padStart(2, "0")}`; };
  App.filmFx = (x, w, h, stamp) => {
    x.save();
    x.globalCompositeOperation = "soft-light"; x.fillStyle = "rgba(255,160,80,.40)"; x.fillRect(0, 0, w, h);
    x.globalCompositeOperation = "source-over";
    const v = x.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.75);
    v.addColorStop(0, "rgba(0,0,0,0)"); v.addColorStop(1, "rgba(0,0,0,.42)"); x.fillStyle = v; x.fillRect(0, 0, w, h);
    if (stamp) {
      const fs = Math.round(Math.min(w, h) * 0.045);
      x.font = `700 ${fs}px "DM Mono", monospace`; x.textAlign = "right";
      x.shadowColor = "rgba(255,90,20,.9)"; x.shadowBlur = fs * 0.4; x.fillStyle = "#ffad5c";
      x.fillText(stamp, w - fs * 0.9, h - fs * 0.9);
    }
    x.restore();
  };
  // Otomatik ışık düzeltme: sarı salon ışığını nötrler, karanlığı açar, kontrastı toparlar (hafif)
  App.enhancePixels = (d) => {
    const n = d.length / 4, step = Math.max(1, Math.floor(n / 60000));
    let sr = 0, sg = 0, sb = 0, cnt = 0;
    for (let i = 0; i < d.length; i += 4 * step) { sr += d[i]; sg += d[i + 1]; sb += d[i + 2]; cnt++; }
    const mr = sr / cnt || 1, mg = sg / cnt || 1, mb = sb / cnt || 1, gray = (mr + mg + mb) / 3;
    const gain = (m) => Math.min(1.25, Math.max(0.8, 1 + 0.6 * (gray / Math.max(m, 1) - 1)));
    const gr = gain(mr), gg = gain(mg), gb = gain(mb);
    const hist = new Uint32Array(256); let lsum = 0;
    for (let i = 0; i < d.length; i += 4 * step) {
      const l = Math.min(255, Math.round(0.299 * d[i] * gr + 0.587 * d[i + 1] * gg + 0.114 * d[i + 2] * gb)); hist[l]++; lsum += l;
    }
    let acc = 0, lo = 0, hi = 255; for (let v = 0; v < 256; v++) { acc += hist[v]; if (acc >= cnt * 0.01) { lo = v; break; } }
    acc = 0; for (let v = 255; v >= 0; v--) { acc += hist[v]; if (acc >= cnt * 0.01) { hi = v; break; } }
    lo = Math.min(lo, 24); hi = Math.max(hi, 200); if (hi - lo < 60) { lo = 0; hi = 255; }
    const mean = Math.max(0.02, (lsum / cnt - lo) / (hi - lo));
    const gamma = mean < 0.4 ? Math.min(1, Math.max(0.62, Math.log(0.45) / Math.log(mean))) : 1;
    const lut = (g) => { const t = new Uint8ClampedArray(256); for (let v = 0; v < 256; v++) { const x = Math.min(1, Math.max(0, (v * g - lo) / (hi - lo))); t[v] = Math.round(255 * Math.pow(x, gamma)); } return t; };
    const Lr = lut(gr), Lg = lut(gg), Lb = lut(gb);
    for (let i = 0; i < d.length; i += 4) { d[i] = Lr[d[i]]; d[i + 1] = Lg[d[i + 1]]; d[i + 2] = Lb[d[i + 2]]; }
  };

  App.processImage = (file, opts = {}) => new Promise((res, rej) => {
    const url = URL.createObjectURL(file); const img = new Image();
    img.onload = () => {
      const max = 1600; let w = img.naturalWidth, h = img.naturalHeight; const k = Math.min(1, max / Math.max(w, h));
      w = Math.round(w * k); h = Math.round(h * k);
      const c = document.createElement("canvas"); c.width = w; c.height = h; const x = c.getContext("2d");
      x.drawImage(img, 0, 0, w, h);
      if (opts.enhance) { try { const id = x.getImageData(0, 0, w, h); App.enhancePixels(id.data); x.putImageData(id, 0, 0); } catch (e) { /* düzeltme olmadan devam */ } }
      if (opts.film) App.filmFx(x, w, h, opts.stamp);
      URL.revokeObjectURL(url);
      c.toBlob((b) => (b ? res(b) : rej(new Error("Fotoğraf işlenemedi."))), "image/jpeg", 0.85);
    };
    img.onerror = () => { URL.revokeObjectURL(url); rej(new Error("Bu dosya açılamadı. Lütfen JPEG/PNG bir fotoğraf seçin.")); };
    img.src = url;
  });

  // Bulanıklık / karanlık kontrolü (telefonda, yüklemeden önce)
  App.checkImage = (file) => new Promise((res) => {
    const url = URL.createObjectURL(file); const img = new Image();
    img.onload = () => {
      try {
        const k = Math.min(1, 480 / Math.max(img.naturalWidth, img.naturalHeight));
        const w = Math.max(8, Math.round(img.naturalWidth * k)), h = Math.max(8, Math.round(img.naturalHeight * k));
        const c = document.createElement("canvas"); c.width = w; c.height = h; const x = c.getContext("2d", { willReadFrequently: true });
        x.drawImage(img, 0, 0, w, h); const d = x.getImageData(0, 0, w, h).data;
        const g = new Float32Array(w * h); let sum = 0;
        for (let i = 0, j = 0; i < d.length; i += 4, j++) { g[j] = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; sum += g[j]; }
        const mean = sum / (w * h);
        let n = 0, m = 0, m2 = 0;
        for (let y = 1; y < h - 1; y++) for (let xx = 1; xx < w - 1; xx++) {
          const i = y * w + xx; const L = 4 * g[i] - g[i - 1] - g[i + 1] - g[i - w] - g[i + w];
          n++; const dl = L - m; m += dl / n; m2 += dl * (L - m);
        }
        const sharp = n ? m2 / n : 999;
        res({ url, blurry: sharp < 35 && mean >= 20, dark: mean < 20 });
      } catch (e) { res({ url, blurry: false, dark: false }); }
    };
    img.onerror = () => res({ url, blurry: false, dark: false });
    img.src = url;
  });

  App.storage = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} },
  };

  App.downloadText = (filename, text, type = "text/csv;charset=utf-8") => {
    const blob = new Blob(["﻿" + text], { type }); const a = document.createElement("a");
    a.href = URL.createObjectURL(blob); a.download = filename; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
  };

  document.addEventListener("DOMContentLoaded", () => {
    if (!configured) {
      const w = document.createElement("div"); w.className = "setup-warning";
      w.innerHTML = "<b>Kurulum tamamlanmadı:</b> <code>config.js</code> dosyasına Supabase adresinizi ve anahtarınızı yazın (KURULUM.md, 3. adım).";
      document.body.prepend(w);
    }
  });
})();
