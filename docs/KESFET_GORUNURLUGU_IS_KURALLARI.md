# Keşfet Görünürlüğü İş Kuralları

Bu doküman, kullanıcıların keşfet listesi ve keşfet aramasında görünme/gizlenme davranışını tek yerde tanımlar.

## Amaç

- Keşfet görünürlüğünü kullanıcı tercihiyle yönetmek
- Kayıt olan her kullanıcı için keşfet kaydı bulunmasını garanti etmek
- Listeleme ve arama sonuçlarında tutarlı davranış sağlamak

## Kapsam

Bu kurallar aşağıdaki alanları kapsar:

- Veritabanı: `discover_listings`
- Auth: kayıt, `me`, görünürlük güncelleme
- Listeleme: keşfet/browse sorguları
- Admin panel: keşfet kullanıcıları görünümü

## Veri Modeli

Tablo: `discover_listings`

- `user_id` (PK, FK -> `users.id`)
- `visible_in_discover` (`boolean`, varsayılan `true`)
- `created_at`
- `updated_at`

İlişki:

- `users` kaydı ile birebir ilişki (`User.discoverListing`)

## Temel İş Kuralları

1. **Kayıtta otomatik oluşturma**  
   Yeni kullanıcı oluşturulduğunda `discover_listings` satırı otomatik açılır ve `visible_in_discover = true` olur.

2. **Varsayılan görünürlük**  
   Aksi bir kullanıcı tercihi yoksa kullanıcı keşfette görünür kabul edilir.

3. **Kullanıcı tercihi önceliği**  
   Kullanıcı profilde “Keşfette görün” seçeneğini kapatırsa, keşfet listesi ve keşfet arama sonuçlarında gösterilmez.

4. **Güvenli güncelleme (upsert)**  
   Görünürlük güncellemesi `upsert` mantığıyla çalışır; satır yoksa oluşturulur, varsa güncellenir.

5. **Listeleme filtresi**  
   Keşfet/browse sorgularında yalnızca:
   - `discoverListing` yoksa (legacy güvenliği)
   - veya `discoverListing.visibleInDiscover = true` ise
   sonuçlara dahil edilir.

6. **Admin görünürlüğü**  
   Admin panelde keşfet kullanıcıları ekranı, hem görünür hem gizli kullanıcıları durumlarıyla birlikte listeler.

## API Sözleşmesi

## Görünürlük güncelleme

- `PATCH /auth/me/discover-visibility`
- Body:

```json
{
  "visibleInDiscover": true
}
```

Başarılı yanıt:

- Güncel `user` nesnesi döner.
- `user.visible_in_discover` alanı güncellenmiş olur.

## User yanıt alanı

Auth user response içinde:

- `visible_in_discover: boolean`

Kaynak endpoint örnekleri:

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

## UI Davranış Kuralı

Profil ekranında:

- “Keşfette görün” toggle değeri `user.visibleInDiscover` ile başlar.
- Toggle değişince API çağrısı yapılır.
- Başarılıysa state güncellenir, başarısızsa kullanıcıya hata mesajı gösterilir.

## Migration ve Backfill Kuralı

Geçmiş kullanıcılar için:

- `discover_listings` tablosu backfill ile doldurulur.
- Toplu sıfırlama senaryosunda tüm kayıtlar `visible_in_discover = true` yapılabilir.

Uygulanan migration örnekleri:

- `20260417100000_discover_listings`
- `20260418120000_backfill_discover_all_users_visible`

## Test Senaryoları (Minimum)

1. Yeni kayıt olan kullanıcı için keşfet satırı oluşur mu?
2. Kullanıcı görünürlüğü kapatınca browse sonuçlarından düşüyor mu?
3. Kullanıcı görünürlüğü açınca tekrar browse sonuçlarına dönüyor mu?
4. `discover_listings` satırı olmayan legacy kullanıcı, filtrede beklenen şekilde ele alınıyor mu?
5. Admin keşfet ekranında gizli/görünür durum doğru görünüyor mu?

## Bilinen Kararlar

- “Keşfette görünme” tercihi, kullanıcının keşfet listesi/arama görünürlüğünü etkiler.
- Bu tercih, hesap silme/askıya alma gibi statü kurallarının yerine geçmez; onlar ayrıca uygulanır.
