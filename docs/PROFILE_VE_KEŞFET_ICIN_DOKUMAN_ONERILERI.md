# Rahatla Docs — Sonraki Eklenebilecek Doküman Önerileri

Bu dosya, mevcut akıştan sonra dokümantasyona eklenebilecek başlıkları öncelik sırasıyla önerir.

## 1) Profil Fotoğrafı (AWS/S3) Akış Dokümanı

Neden önemli:
- Yeni eklenen profil fotoğrafı yükleme özelliğinin sınırları ve güvenlik kuralları netleşir.

Neleri içersin:
- `POST /media/profile-image` akışı (boyut limiti, mime tipleri)
- `PATCH /auth/me/profile-images` ile liste kaydetme/sıralama
- En fazla fotoğraf sayısı, silme davranışı
- Hata durumları (`400`, `401`) ve kullanıcıya gösterilecek mesajlar
- S3 klasör yapısı: `profile-images/{userId}/...`

## 2) Keşfet Görünürlüğü İş Kuralı Dokümanı

Neden önemli:
- "Keşfette görün / görünme" artık birden fazla katmanı etkiliyor (register, browse, admin, profil).

Neleri içersin:
- `discover_listings` tablosu mantığı
- Register sırasında otomatik kayıt
- Kullanıcı gizliyse hangi listelerde görünmez olacağı
- Admin panelde "Keşfet kullanıcıları" ekranı kullanım amacı
- Backfill/migration stratejisi

## 3) Rol Bazlı Ekran Matrisi (Mobile)

Neden önemli:
- `normal_user`, `listener_applicant`, `approved_listener`, `admin` için hangi kart/ayar görünecek sorusu sık karışır.

Neleri içersin:
- Profil ekranında rol bazlı görünürlük tablosu
- Hangi rolde hangi API çağrıları aktif
- Hangi rolde hangi butonlar gizlenir

## 4) API Sözleşmesi (Frontend için Tek Kaynak)

Neden önemli:
- Mobil ve admin panel için payload anahtarlarının (`snake_case`/`camelCase`) tek kaynakta doğrulanması hata azaltır.

Neleri içersin:
- Auth user response alanları (`visible_in_discover`, `profile_image_urls`, vb.)
- Örnek request/response gövdeleri
- Validasyon kuralları ve limitler

## 5) Hata Mesajı ve UX Metin Rehberi

Neden önemli:
- Kullanıcıya çıkan mesajlar şu an dağınık; aynı hataya farklı metinler çıkabiliyor.

Neleri içersin:
- Ortak hata kodu -> kullanıcı metni eşlemesi
- Toast/SnackBar dili (kısa, aksiyon odaklı)
- Teknik detay gizleme ilkesi (internal error’ı kullanıcıya açmama)

## 6) Operasyon Runbook (Kısa)

Neden önemli:
- Production’da migration, env ve servis ayağa kaldırma adımları tek yerde olmalı.

Neleri içersin:
- Deploy sonrası çalıştırılacak komutlar
- `prisma migrate deploy` sırası
- Zorunlu env listesi (JWT, DB, S3)
- Basit smoke test checklist

## 7) Test Senaryosu Checklist (QA)

Neden önemli:
- Özellikle keşfet görünürlüğü ve profil fotoğrafları regresyona açık.

Neleri içersin:
- Kullanıcı kayıt -> keşfete otomatik eklenme testi
- Keşfette görünme kapat/aç testi
- Profil fotoğrafı ekle/sil/limit aşımı testleri
- Admin panel keşfet listesi doğrulama

---

## Önerilen Uygulama Sırası

1. Profil Fotoğrafı (AWS/S3) akış dokümanı
2. Keşfet görünürlüğü iş kuralı
3. API sözleşmesi (frontend referansı)
4. QA checklist
5. Operasyon runbook

Bu sırayla gidersen hem geliştirme hem QA hem de canlıya geçiş tarafı daha az sürprizli olur.
