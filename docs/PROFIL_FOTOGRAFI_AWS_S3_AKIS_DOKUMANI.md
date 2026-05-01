# Profil Fotoğrafı AWS/S3 Akış Dokümanı

Bu doküman, mobilde profil fotoğrafı ekleme/silme özelliğinin API + S3 + veritabanı akışını tek yerde açıklar.

## Amaç

- Kullanıcı kendi profiline birden fazla fotoğraf ekleyebilsin.
- Fotoğraflar güvenli şekilde S3 uyumlu object storage'a yüklensin.
- Profilde gösterilecek fotoğraf listesi veritabanında tutulsun.
- Mobil uygulama, bu listeyi `auth/me` üzerinden okuyup gösterebilsin.

## Mimari Özet

Akış iki adımdır:

1. **Dosya yükleme**  
   `POST /media/profile-image` ile dosya S3'e yüklenir, URL döner.

2. **Profil listesine yazma**  
   `PATCH /auth/me/profile-images` ile URL listesi `profiles.profile_image_urls` alanına kaydedilir.

Bu tasarımın sebebi: dosya aktarımı ile profil tercih güncellemesini ayrıştırmak.

## Veri Modeli

`profiles` tablosunda:

- `profile_image_urls TEXT[] NOT NULL DEFAULT []`

Notlar:

- Dizi sıralıdır; mobil tarafta bu sıra korunur.
- Mevcut davranışta maksimum 9 URL desteklenir.

## Gerekli Ortam Değişkenleri

S3 yükleme akışının çalışması için API tarafında aşağıdakiler zorunludur:

- `S3_ENDPOINT`
- `S3_ACCESS_KEY_ID`
- `S3_SECRET_ACCESS_KEY`
- `S3_BUCKET`

Opsiyonel:

- `S3_REGION` (yoksa `auto`)
- `S3_PUBLIC_BASE_URL` (varsa public URL üretiminde bu kullanılır)

## API Uçları

### 1) Profil görselini S3'e yükleme

`POST /media/profile-image`

- Auth: `Bearer` zorunlu (`JwtAuthGuard`)
- Content-Type: `multipart/form-data`
- Form alanı: `file`
- Limit: 8 MB
- Desteklenen mime:
  - `image/jpeg`
  - `image/jpg`
  - `image/png`
  - `image/webp`

Başarılı yanıt:

```json
{
  "key": "profile-images/<userId>/<timestamp>-<uuid>.jpg",
  "url": "https://.../profile-images/<userId>/..."
}
```

Hata durumları:

- `400 file alanı gerekli`
- `400 Sadece görsel yüklenebilir`
- `400 Desteklenen türler: JPG, PNG, WEBP`
- `401 Unauthorized`

### 2) Profil görsel URL listesini kaydetme

`PATCH /auth/me/profile-images`

- Auth: `Bearer` zorunlu
- Body:

```json
{
  "imageUrls": [
    "https://.../profile-images/u1/a.jpg",
    "https://.../profile-images/u1/b.jpg"
  ]
}
```

Kurallar:

- `imageUrls` dizi olmalı
- en fazla 9 öğe
- her öğe string olmalı
- boş string kabul edilmez
- URL uzunluğu en fazla 2048 karakter

Başarılı yanıt:

- `auth/me` formatında güncel `user` objesi döner.
- `profile_image_urls` alanı güncellenmiş olur.

Hata durumları:

- `400 imageUrls dizi olmalı`
- `400 En fazla 9 görsel tanımlanabilir`
- `400 Her öğe metin olmalı`
- `400 Boş URL kullanılamaz`
- `400 URL çok uzun`

## S3 Key Konvansiyonu

Profil görselleri için key formatı:

- `profile-images/{userId}/{Date.now()}-{uuid}.{ext}`

Avantaj:

- Kullanıcı bazında klasörleme
- Çakışma riskini azaltan timestamp + UUID
- Operasyonel takip kolaylığı

## Mobil Entegrasyon Akışı

Önerilen istemci sırası:

1. Galeriden görsel seç (`image_picker`)
2. `POST /media/profile-image` çağrısı yap
3. Dönen `url` değerini mevcut listeye ekle
4. Yeni listeyi `PATCH /auth/me/profile-images` ile kaydet
5. Başarılıysa UI state'i `auth/me` yanıtıyla güncelle

Silme davranışı:

- URL'yi listeden çıkar
- Kalan listeyi tekrar `PATCH /auth/me/profile-images` ile gönder

Not:

- Mevcut tasarımda S3 objesi fiziksel olarak silinmiyor; sadece listeden çıkarılıyor.

## Güvenlik ve Doğrulama

- Upload endpoint JWT ile korunur.
- Yalnızca görsel mime tipleri kabul edilir.
- Boyut limiti backend'de enforce edilir.
- URL listesi yazımı backend validasyonundan geçer.

Ek öneriler (sonraki iterasyon):

- URL domain allow-list kontrolü (`S3_PUBLIC_BASE_URL` veya bucket endpoint)
- Upload sonrası image processing (thumbnail, strip metadata)
- S3 lifecycle policy (yetim dosya temizliği)

## Örnek cURL

### Upload

```bash
curl -X POST "$API_BASE/media/profile-image" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/photo.jpg"
```

### Listeyi kaydet

```bash
curl -X PATCH "$API_BASE/auth/me/profile-images" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"imageUrls":["https://cdn.example.com/profile-images/u1/p1.jpg"]}'
```

## Operasyon Notu

Migration uygulaması:

```bash
cd apps/api
npx prisma migrate deploy
```

Yerelde doğrulama:

1. Giriş yap, token al
2. Upload endpoint ile dosya yükle
3. `PATCH /auth/me/profile-images` ile URL ekle
4. `GET /auth/me` içinde `profile_image_urls` alanını kontrol et
