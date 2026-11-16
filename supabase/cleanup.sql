-- Anı Kamerası: süresi dolan albümlerin otomatik silinmesi (uygulandı: ani_kamerasi_auto_cleanup)
-- pg_cron her gece 01:17 UTC (04:17 İstanbul) ak-cleanup Edge Function'ını çağırır.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
-- vault'ta 'ak_cleanup_secret' adlı rastgele anahtar oluşturulur (değeri burada yok).
-- public.ak_cleanup_secret_ok(p text) → sadece service_role çalıştırabilir.
-- cron.schedule('ak-cleanup-daily', '17 1 * * *', net.http_post(... x-ak-cron: vault anahtarı ...));
