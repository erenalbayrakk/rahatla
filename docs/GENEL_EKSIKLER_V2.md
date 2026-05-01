# Rahatla — Genel Eksikler V2 (P0 / P1 / P2)

Bu doküman, mevcut üründe "en çok etki eden eksikleri" öncelik ve efor bazlı sıralar.

## Öncelik Mantığı

- **P0:** Canlı kalite/güvenlik/operasyon açısından kritik; gecikirse ciddi risk.
- **P1:** Ürün kalitesini ve kullanıcı deneyimini belirgin artırır.
- **P2:** İyileştirme ve ölçeklenebilirlik odaklı, orta vadeli işler.

Efor:

- **S:** 0.5-2 gün
- **M:** 2-5 gün
- **L:** 1+ hafta

---

## P0 — Kritik Eksikler

## 1) Push Notification Altyapısı (Mesaj / Davet / Sistem)

- **Neden kritik:** Uygulama kapalıyken kullanıcı yeni mesajı görmüyor; yanıt süreleri uzuyor.
- **Etkilenen alanlar:** `apps/api` (notification endpoint/queue), `apps/mobile` (FCM/APNs token yönetimi, permission akışı).
- **Efor:** L
- **İlk adım:**
  - Token register endpoint
  - Yeni mesaj ve grup daveti için tetikleyici
  - Mobilde foreground/background handling

## 2) Medya Yaşam Döngüsü (S3 Yetim Dosya Temizliği)

- **Neden kritik:** Profilden silinen görseller S3'te kalırsa depolama ve maliyet şişer.
- **Etkilenen alanlar:** `apps/api/src/media`, `apps/api/src/auth`, S3 lifecycle.
- **Efor:** M
- **İlk adım:**
  - "Silinen URL'leri tespit et" servisi
  - Güvenli fiziksel silme (soft-delay ile)
  - Haftalık cleanup job

## 3) Güvenlik Sertleştirme (Upload + Auth Rate Limit)

- **Neden kritik:** Abuse/spam/brute force riski yüksek.
- **Etkilenen alanlar:** auth endpointleri, media upload endpointleri.
- **Efor:** M
- **İlk adım:**
  - IP/user bazlı rate-limit
  - Upload başına daha sıkı validasyon (mime sniffing, boyut)
  - Audit loglarda şüpheli pattern işaretleme

## 4) Üretim Gözlemlenebilirlik (Error Tracking + Metrikler)

- **Neden kritik:** Prod sorunlarını hızlı görmek/kök neden bulmak zor.
- **Etkilenen alanlar:** API ve mobile runtime.
- **Efor:** M
- **İlk adım:**
  - Merkezi error tracking (örn. Sentry)
  - API health/latency/error rate metriği
  - Kritik endpoint dashboard'u

---

## P1 — Yüksek Etkili İyileştirmeler

## 5) Otomatik Test Kapsamı (Keşfet + Profil Medya + Rol Erişim)

- **Neden önemli:** Yeni özellikler regression'a açık.
- **Etkilenen alanlar:** API integration/e2e, mobil state/widget test.
- **Efor:** M-L
- **İlk adım:**
  - Keşfet görünürlüğü senaryoları
  - Profil fotoğrafı ekle/sil/limit testleri
  - Admin-only endpoint yetki testleri

## 6) API Contract Tek Kaynak (Payload Sözleşmesi)

- **Neden önemli:** snake_case/camelCase drift hataları azalır.
- **Etkilenen alanlar:** docs + backend dto + mobile mapping.
- **Efor:** S-M
- **İlk adım:**
  - Kritik endpointler için request/response örnekleri
  - Versiyonlama notları
  - Değişiklikte zorunlu güncelleme checklist

## 7) Keşfet Kalite Sinyalleri ve Sıralama

- **Neden önemli:** Keşfet deneyimi daha isabetli olur.
- **Etkilenen alanlar:** `listeners/browse`, mobil listeleme UI.
- **Efor:** M
- **İlk adım:**
  - "Yeni", "aktif", "puanı yüksek" gibi sıralama seçenekleri
  - Basit ve anlaşılır filtreler (gender/age dışında)

## 8) Grup Sohbet Moderasyon Güçlendirmesi

- **Neden önemli:** Topluluk güvenliği ve içerik kalitesi.
- **Etkilenen alanlar:** group chat admin araçları.
- **Efor:** M
- **İlk adım:**
  - Hızlı kullanıcı susturma/kick
  - Anahtar kelime alarmı
  - Moderasyon aksiyon logu

---

## P2 — Orta Vadeli Geliştirmeler

## 9) Onboarding Kişiselleştirme

- **Neden:** İlk oturum dönüşümünü artırır.
- **Efor:** M
- **İlk adım:** role/mood bazlı ilk ekran akışları.

## 10) Profil Zenginleştirme

- **Neden:** Güven ve ifade alanını artırır.
- **Efor:** M
- **İlk adım:** bio, ilgi etiketleri, kısa intro medya.

## 11) Operasyon Runbook + Incident Playbook

- **Neden:** Kriz anında hız ve tutarlılık sağlar.
- **Efor:** S-M
- **İlk adım:** deploy, rollback, migration, smoke-test adımları.

## 12) Feature Flag Altyapısı

- **Neden:** Riskli özellikleri kademeli açmak kolaylaşır.
- **Efor:** M-L
- **İlk adım:** keşfet ve medya özellikleri için basit flag katmanı.

---

## Önerilen Yol Haritası (6 Hafta Örnek)

## Hafta 1-2 (P0 odak)

- Push tasarım + token altyapısı
- Upload/auth rate limit
- Error tracking + temel dashboard

## Hafta 3-4 (P1 odak)

- Keşfet/profil medya test otomasyonu
- API contract dokümantasyonu
- Keşfet sıralama filtreleri

## Hafta 5-6 (P2 başlangıç)

- Onboarding iyileştirmeleri
- Operasyon runbook
- Feature flag başlangıcı

---

## Hızlı Kazançlar (Bu Hafta Yapılabilecek 5 İş)

1. Auth ve media endpointlerine rate-limit ekle. (S)
2. Keşfet görünürlüğü için integration test yaz. (S)
3. Profil foto silmede "S3 delete queue" TODO + log ekle. (S)
4. API contract md dosyasını kritik endpointlerle çıkar. (S)
5. Prod error tracking'i minimum seviyede aktive et. (S-M)

