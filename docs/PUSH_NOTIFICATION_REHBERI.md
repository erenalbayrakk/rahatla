# Push bildirim rehberi — Firebase (FCM)

Bu doküman, Rahatla mobil uygulamasında **Firebase Cloud Messaging (FCM)** ile push bildirimi kullanma kararını ve **nelerin hazırlanması gerektiğini** listeler. Mesaj içeriği ve sohbet geçmişi **PostgreSQL’de kalır**; Firebase yalnızca cihaza **bildirim taşımak** ve **FCM token** yönetimi içindir.

**Firebase Console:** Uygulama eklerken **Flutter** seçeneği kullanılır ([resmi Flutter + Firebase akışı](https://firebase.google.com/docs/flutter/setup)); bu sihirbaz hem **iOS bundle ID** hem **Android application ID** ile projede iki uygulama kaydı oluşturur ve yapılandırma dosyalarını Flutter projesine uygun şekilde hatırlatır.

**Teslimat sırası:** Kod ve testte önce **iOS** (Faz 1); sonra **Android** Gradle / kanal / doğrulama (Faz 2). Firebase’de Flutter ile kayıt yapılmış olsa bile `google-services.json` ve Android Gradle adımları Faz 2’ye bırakılabilir — iOS için `GoogleService-Info.plist` ve Xcode yeterlidir.

---

## 1. Kısa hatırlatma: Ne ne işe yarar?

| Kavram | Açıklama |
|--------|-----------|
| **Push (FCM)** | Uygulama arka planda/kapalıyken kilit ekranı ve bildirim gölgesinde uyarı. |
| **Socket / gerçek zamanlı** | Uygulama açıkken sohbet güncellemesi (projede `socket_io_client` ile). |
| **PostgreSQL** | Mesajlar, oturumlar — **buraya taşınmaz**, kaynak doğruluk burada kalır. |

---

## 2. Mimari özet (FCM ile)

1. **Firebase Console**’da tek proje; uygulama eklerken **Flutter** seçilir — Console’da iOS ve Android **uygulama kayıtları** birlikte oluşur (Flutter tek motor değildir; FCM yine aynıdır).
2. Mobil uygulama açılışında **FCM registration token** alınır → **Rahatla API**’ye gönderilir (`platform: ios` veya ileride `android`).
3. Yeni mesaj kaydedildiğinde backend, alıcının token’larına **HTTP v1** veya **Admin SDK** ile FCM çağrısı yapar.
4. **Android:** Faz 2’de bildirim **kanalı** ve Gradle ayarları eklenir; iOS’ta kanal kavramı yoktur.

---

## 3. Karar

**Push sağlayıcı:** Google **Firebase — Cloud Messaging (FCM)**.  
**Chat verisi:** Mevcut **DB şeması** (ör. `Message`, `GroupChatMessage`); Firebase’e taşıma yok.  
**Kayıt yolu:** Firebase **Flutter** sihirbazı. **Teslim sırası:** **Önce iOS**, sonra **Android** (yapılandırma ve test).

---

## 4. Neler lazım? — Faz 1: yalnızca iOS

Bu fazda hedef: fiziksel iPhone’da FCM token almak, API’ye kaydetmek ve sunucudan test bildirimi göndermek. **Android native/config adımları Faz 2’ye kalabilir** (Firebase’de uygulama kaydı Flutter sihirbazında zaten oluşmuş olabilir).

### Faz 1 — A) Hesaplar ve Firebase (Flutter ile kayıt)

| # | Görev | Not |
|---|--------|-----|
| 1 | **Google hesabı** ile [Firebase Console](https://console.firebase.google.com/) — proje oluştur | Tek proje, hem platformlar için. |
| 2 | Proje oluştururken / sonrasında **Add app → Flutter** (veya eşdeğer Flutter girişi) | iOS **bundle ID** + Android **applicationId** sorulur; Xcode ve `android/app/build.gradle.kts` ile **birebir** aynı girilmeli (Rahatla örneği: iOS `com.rahatla.rahatlaMobile`, Android `com.rahatla.rahatla_mobile`). |
| 3 | **Google Cloud**: **Firebase Cloud Messaging API** etkin | Sunucudan gönderim (HTTP v1 / Admin SDK) için. |
| 4 | **Apple Developer Program** — iOS push için zorunlu | APNs Auth Key (.p8). |
| 5 | **GoogleService-Info.plist** indir → `ios/Runner/` ve Xcode’da projeye dahil et | Flutter dokümantasyonundaki konum. |
| 6 | (İsteğe bağlı bu fazda) **google-services.json** → `android/app/` | Flutter sihirbazı genelde verir; Faz 2’ye kadar repo’da durabilir, Android build henüz tamamlanmayabilir. |
| 7 | Firebase → Project settings → Cloud Messaging → **APNs authentication key** (.p8) yükle | Apple Developer → Keys → APNs işaretli anahtar. |

---

### Faz 1 — B) Xcode / iOS proje ayarları

| # | Görev | Not |
|---|--------|-----|
| 1 | **Signing & Capabilities** → **Push Notifications** | Kapalıysa eklenmeli. |
| 2 | **Background Modes** → **Remote notifications** | Arka planda data işlemek için genelde açılır. |
| 3 | Bildirim izni zamanlaması (ilk açılışta mı, ilk mesajda mı) ürün kararı | Kodda `requestPermission` çağrısı. |
| 4 | Test için **gerçek cihaz** kullan | Push, simülatörde tam olarak güvenilir değildir; fiziksel iPhone önerilir. |

---

### Faz 1 — C) Flutter (`apps/mobile`) — bu fazda yapılacaklar

| # | Görev | Not |
|---|--------|-----|
| 1 | `pubspec.yaml`: **`firebase_core`**, **`firebase_messaging`** | |
| 2 | **FlutterFire CLI:** `dart pub global activate flutterfire_cli` → proje kökünde **`flutterfire configure`** | Firebase’de Flutter ile oluşturduğun projeyi seç; iOS/Android uygulamaları eşleşir; `firebase_options.dart` üretilir — [FlutterFire](https://firebase.flutter.dev/docs/cli) şablonuna uy. |
| 3 | `main.dart`: `WidgetsFlutterBinding.ensureInitialized()` sonrası **`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`** (FlutterFire çıktısına göre) | |
| 4 | `FirebaseMessaging.instance.getToken()` / `onTokenRefresh` → **API’ye POST**, `platform: ios` | |
| 5 | iOS: FlutterFire **messaging / iOS** adımları | Örn. foreground için `setForegroundNotificationPresentationOptions`. |

**Mevcut durum:** `pubspec.yaml` içinde henüz `firebase_*` yok; Faz 1 ile eklenecek.

---

### Faz 2 — Android tamamlandığında (özet)

Flutter + Firebase ile Console’da Android uygulaması **zaten kayıtlı olabilir**; bu fazda eksik kalanları bitirirsin:

| Alan | Ek iş |
|------|--------|
| **Dosyalar** | **google-services.json** `android/app/` içinde (yoksa indir / `flutterfire configure` tekrar). |
| **Gradle** | Root + `android/app` içinde Google Services eklentisi — [Flutter dokümantasyonu](https://firebase.google.com/docs/flutter/setup?platform=android). |
| **Flutter** | Gerekirse `flutterfire configure` yeniden çalıştırıp `firebase_options.dart` güncelle. |
| **Kod** | Bildirim **channel** (Android 8+); token kaydında `platform: android`. |
| **Backend** | Aynı tablo / endpoint; gönderimde hem `ios` hem `android` token’ları. |

Faz 2 öncesi backend’de `platform` genelde `ios` ile test edilir.

---

### E) Backend (`apps/api`) — token saklama ve gönderim (her iki faz için ortak)

| # | Görev | Not |
|---|--------|-----|
| 1 | **Prisma modeli** (örnek): `PushDevice` veya `UserDeviceToken` — `userId`, `fcmToken`, `platform` (`ios`/`android`), `updatedAt`, isteğe bağlı `lastSeenAt` | Çoklu cihaz için aynı kullanıcıya birden fazla satır. |
| 2 | **REST endpoint’ler** | Örn. `POST /notifications/device-token` (JWT): token kayıt/güncelleme; `DELETE` ile çıkış/silme. |
| 3 | **Firebase Admin SDK** (`firebase-admin` npm) **veya** HTTP v1 ile OAuth2 | Servis hesabı JSON ile sunucuda kimlik doğrulama. |
| 4 | Ortam değişkenleri | Örn. `FIREBASE_SERVICE_ACCOUNT_JSON` (base64 veya dosya yolu — üretimde Secret Manager önerilir). `.env.example` güncellenmeli. |
| 5 | **Gönderim servisi**: mesaj kaydından sonra ilgili kullanıcıların token’larına `sendEachForMulticast` benzeri çağrı | Başarısız token’ları (unregistered) DB’den temizleme iyi pratik. |
| 6 | Payload: **data** alanında `sessionId` / `roomId` / `type` | Uygulama bildirime tıklayınca doğru sohbete gider. |

**Mevcut durum:** Uygulama içi **Notification** modeli (in-app liste) ile **FCM push** farklı kavramlar; FCM için ayrı tablo ve gönderim kodu eklenmeli.

---

### F) Güvenlik ve operasyon

| # | Görev | Not |
|---|--------|-----|
| 1 | Servis hesabı JSON **asla** repoya commit edilmez | CI/CD veya `.gitignore`. |
| 2 | Rate limit ve hata loglama | FCM quota ve hatalı token senaryoları. |
| 3 | Kullanıcı ayarı: “Bildirimleri kapat” | İleride ayarlar ekranından token silme veya sunucuda “push kapalı” bayrağı. |

---

## 5. Uygulama sırası (önerilen PR sırası)

### Faz 1 — iOS

1. Firebase projesi — uygulama eklerken **Flutter** seçeneği + bundle ID / package name + **GoogleService-Info.plist** + APNs **.p8**’in Firebase’e bağlanması.
2. Xcode: Push Notifications + Background Remote notifications.
3. Flutter: `firebase_core` / `firebase_messaging`, `Firebase.initializeApp()`, iOS’ta token alıp log veya geçici ekranda doğrulama.
4. API: token tablosu + kayıt endpoint’i + mobilde token’ı `platform: ios` ile gönderme.
5. API: `firebase-admin` + ortam değişkeni + **tek iOS cihaza** test push.
6. Mesaj akışına push tetikleyicisi (önce tek alıcı / test).
7. İsteğe bağlı: bildirim tıklayınca `go_router` ile doğru sohbet route’u.

### Faz 2 — Android (Faz 1 stabil olduktan sonra)

1. **google-services.json** + Gradle Google Services eklentisi (Flutter kaydında Android zaten varsa sadece yapılandırmayı tamamla).
2. Bildirim kanalı ve Android’e özel test.
3. Token kayıtlarında `platform: android`; gönderimde her iki platform token’ı.
4. İsteğe bağlı: `flutter_local_notifications` ile kanal detayı ve foreground tutarlılığı.

---

## 6. Alternatifler (kısa — referans)

FCM dışında OneSignal, Amazon SNS, doğrudan APNs vb. mümkün; karar **Firebase** olarak sabitlendi. Geniş karşılaştırma için geçmişteki değerlendirme notları gerektiğinde ayrı dokümanda toplanabilir.

---

## 7. Yönetim panelinden test push

Üretimde ayrı bir Vite uygulaması yok; yönetim arayüzü API’nin statik olarak servis ettiği dosyadır:

- **URL:** `http://localhost:3000/admin-panel/` (veya `APP_PUBLIC_API_URL` + `/admin-panel/`)
- **Dosya:** `apps/api/admin-panel/index.html`
- Admin olarak giriş yaptıktan sonra sol menüde **«Test push»** ile `POST /admin/push/test` çağrılır (FCM token + başlık/gövde).

API imajı / süreç yenilendiğinde bu HTML güncellenir; Docker kullanıyorsan `docker compose up -d --build api` ile yeniden derleyin.

---

## 8. Dış bağlantılar

- [Add Firebase to your Flutter app](https://firebase.google.com/docs/flutter/setup) — Console’da **Flutter** seçimi ve adımlar
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire — Messaging](https://firebase.flutter.dev/docs/messaging/overview/)
- [HTTP v1 API](https://firebase.google.com/docs/cloud-messaging/migrate-v1) (sunucu gönderimi)
- [Apple — Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)

---

*Son güncelleme: Test push yalnızca `apps/api/admin-panel/` ( `/admin-panel/` ) üzerinden; ayrı Vite admin uygulaması yok.*
