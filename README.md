# DockSense

macOS için küçük bir menü çubuğu uygulaması. Bir pencere bir ekranın kullanılabilir alanını tamamen kapladığında Dock'u otomatik gizler; aksi durumda Dock'u görünür tutar.

MasaustuDock projesinin yeniden adlandırılmış, daha az periyodik kontrol yapacak şekilde düzenlenmiş sürümüdür. Kaynak kod Objective-C'dir; üçüncü taraf bağımlılık yoktur.

## Durum

Geliştirme sürümü. Derleme, gerçek masaüstü davranışı ve pil ölçümleri tamamlanmadan doğrulanmış sürüm olarak değerlendirilmemelidir. Kontrol sonuçları `VALIDATION.md` dosyasındadır.

## Enerji yaklaşımı

- Erişilebilirlik izniyle ön plandaki uygulamanın pencere hareketleri ve boyut değişiklikleri dinlenir.
- Art arda gelen olaylar 250 ms içinde birleştirilir.
- Uygulama, Space ve ekran değişiklikleri sistem bildirimlerinden takip edilir.
- Desteklenen pencere bildirimleri varsa 15 saniyelik yedek kontrol kullanılır. İzin yoksa veya uygulama bildirimleri desteklemiyorsa aralık 3 saniyedir.
- Yedek zamanlayıcıda %20 tolerans vardır; sistem kontrolleri başka işlerle birleştirebilir.
- Uyku, ekran kapanması ve kullanıcı oturumunun pasifleşmesi sırasında tarama durur.
- Dock ayarı yalnızca gerektiğinde değiştirilir.

Eski sürüm 0,4 saniyede bir tarıyordu: saatte yaklaşık 9.000 zamanlanmış kontrol. Olay olmayan durumda yeni sürüm nominal olarak 240 (15 sn) veya 1.200 (3 sn) kontrol planlar. Bunlar pil tasarrufu ölçümü değildir; pencere olayları ek kontrol oluşturur ve toplam enerji tüketimi ayrıca ölçülmelidir.

## Gereksinimler ve derleme

- macOS 11 veya üzeri; Intel ya da Apple Silicon.
- Apple Command Line Tools veya Xcode. Kurulum: `xcode-select --install`.

```sh
sh tests/run.sh
open build/DockSense.app
```

Derleme iki işlemci mimarisini içerir ve yerel ad-hoc imza uygular. Developer ID imzası veya Apple notarizasyonu içermez. Betik derleme/imza hatalarını gizlemez; başarısız derlemede eski uygulamayı korur.

## Kullanım

1. Önce eski MasaustuDock uygulamasından çıkın; iki uygulama aynı Dock ayarını yönetmemeli.
2. DockSense'i çalıştırın. Menü çubuğunda **DS** görünür.
3. İsteğe bağlı olarak **Verimli mod için erişim izni ver…** öğesini seçin ve Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik bölümünden izin verin. İzin vermeden de seyrek kontrol modu çalışır.
4. **Durum ve kontrol sayısı…** öğesi etkin modu ve tarama sayısını gösterir.
5. **DockSense'ten Çık**, uygulama başlatılırken geçerli olan Dock ayarını geri yükler.

Salt okunur teşhis:

```sh
build/DockSense.app/Contents/MacOS/DockSense --diagnose
```

Bu komut Dock ayarını değiştirmez ve pencere başlıklarını yazdırmaz. Uygulama ağ bağlantısı kurmaz veya telemetri göndermez.

## Bilinen sınırlar

- Dock kontrolü, orijinal projedeki belgelenmemiş `CoreDock` işlevlerine bağımlıdır. İşlevler bulunamazsa uygulama ayarı değiştirmeden hata gösterir. Gelecekteki macOS uyumluluğu garanti edilmez.
- Herhangi bir monitörü kaplayan pencere otomatik gizlemeyi tetikler. Yalnızca Dock'un bulunduğu monitörü seçme özelliği yoktur.
- Ön planda olmayan uygulamaların veya bildirim göndermeyen uygulamaların değişiklikleri yedek kontrole kadar gecikebilir; bu gecikme olay modunda yaklaşık 15 saniye ve zamanlayıcı toleransı kadar olabilir.
- Başlangıçta ve ekran düzeni/uyanma değişikliklerinde kullanılabilir alanı ölçmek için Dock kısa süreliğine görünür olabilir.
- Zorla kapatma veya çökme durumunda eski Dock ayarı geri yüklenmeyebilir.
- DockSense çalışırken sistemin Dock otomatik gizleme ayarını yönetir; elle yapılan değişiklikler bir sonraki kontrolde geçersiz kalabilir.
- Otomatik başlangıç, uygulama simgesi ve notarize edilmiş dağıtım bu sürümde yoktur.

## Test

`sh tests/run.sh` 16 geometri/zamanlama doğrulamasını çalıştırır, iki mimari için derler ve paket imzasını doğrular. GitHub Actions aynı kontrolleri macOS üzerinde çalıştıracak şekilde hazırlanmıştır. Bu otomatik kontroller gerçek masaüstü ve pil testlerinin yerine geçmez; manuel liste `VALIDATION.md` içindedir.

## Teknik kaynaklar

- [Apple: AXObserverCreate](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate)
- [Apple: AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification)
- [Apple: NSWorkspace uygulama bildirimleri](https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification)
