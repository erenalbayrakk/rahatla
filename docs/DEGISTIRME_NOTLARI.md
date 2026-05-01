# Degistirme Notlari

## 2026-04-24

- Register ekraninda selfie secimindeki dosya adi metni kaldirildi; sadece "Selfie eklendi." gosteriliyor.
- Register ekraninda "Resim ekle" (galeri) secenegi kaldirildi; selfie icin sadece kamera akisi birakildi.
- Tema gecisinde ara renk/flicker gorunmesi azaltildi; uygulama genelinde tema gecisi anlik hale getirildi.
- Sohbet, wallet ve leaderboard ekranlarinda sabit acik renkler kaldirilarak tema uyumlu renkler kullanildi.
- Leaderboard, wallet icindeki karttan kaldirildi ve alt menude ayri sekme olarak cüzdan ile profil arasina tasindi.
- Register'daki kullanim kosullari ve gizlilik politikasi metinleri popup (bottom sheet) akisina alindi:
  - Metin sonuna kadar scroll edilmeden "Okudum, tamam" aktif olmuyor.
  - Iki metin de tamamlanmadan "okudum ve kabul ediyorum" secilemiyor.
- Mobilde API hatalari merkezi hale getirildi:
  - `ApiException.fromDio(...)` eklendi.
  - Status ve baglanti tipine gore kullaniciya daha net mesajlar veriliyor.
  - Birden fazla repository'deki tekrar eden `_mapDio` kodu merkezilesitirildi.
- Selfie tekrar sorma bug'i icin onboarding akisi guclendirildi:
  - Yeni cache alani: `selfie_step_completed`.
  - Register'da selfie yukleme basarili olunca `selfie_step_completed=true`.
  - Onboarding, `verifySelfieUrl` gec gelirse bile `selfie_step_completed=true` oldugunda selfie adimini tekrar zorlamiyor.
- Koyu mod renk duzeltmeleri:
  - `group_rooms_screen` icindeki sabit acik tab zemini kaldirildi.
  - `notifications_screen` tema uyumlu hale getirildi (liste zemini ve metin renkleri).
  - `wallet_screen` kalan beyaz kart zemini tema uyumlu hale getirildi.
  - `chat_screen` ve `group_chat_screen` icindeki sabit beyaz/acik tonlar tema tabanli renklere cekildi (app bar, wallpaper, composer, emoji paneli ve message bubble renkleri).
- Onboarding + profil galeri guncellemesi:
  - Onboarding selfie adimina, kutuphaneden profil gorseli ekleme alani eklendi.
  - Onboarding'de secilen profil gorselleri (en fazla 6) onboarding tamamlanirken API'ye yuklenip profile kaydediliyor.
  - Profil ekranindaki maksimum profil gorseli limiti 6 olarak guncellendi (onboarding ile ayni limit).
