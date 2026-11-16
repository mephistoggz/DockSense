# Doğrulama durumu

Bu dosya yalnızca gerçekten tamamlanan kontrolleri kaydeder.

## Tamamlanan kontroller

- `sh -n build.sh`, `sh -n tests/run.sh`, `sh -n tests/build_safety.sh`: kabuk sözdizimi kontrolleri geçti.
- `plutil -lint Info.plist`: uygulama ayar dosyası geçerli.
- `sh tests/build_safety.sh`: gerçek derleme betiği, sahte derleyici/imzalayıcı ile altı senaryoda çalıştırıldı. Eksik derleyici, derleme hatası, mimari kontrol hatası, imzalama hatası ve imza doğrulama hatasında önceki uygulama korundu; başarılı senaryoda yeni paket yerini aldı. Geçici derleme klasörleri hata yollarında temizlendi.
- `sh build.sh`: gerçek derleme denendi; Apple Command Line Tools bulunmadığı için beklenen açıklamayla durdu. Bu sonuç derlemenin geçtiği anlamına gelmez.
- Kaynak incelemesinde Dock görünürlüğünden kaynaklanabilecek ekran bildirimlerinin yeniden ölçüm döngüsü başlatmaması için ekran kimliği/konumu/ölçeği kontrolü eklendi. Bu korumanın masaüstünde doğrulanması hâlâ gerekiyor.

## Henüz tamamlanmayanlar

- C politika testlerinin çalıştırılması, Objective-C derlemesi, universal mimari ve uygulama imza doğrulaması: Apple Command Line Tools kurulumu bekleniyor.
- Gerçek Dock davranışı, Erişilebilirlik bildirimlerinin alınması ve pil/CPU ölçümü: derlemeden sonra yapılacak.
- GitHub yayını ve CI sonucu: hesap bağlantısı ve testler bekleniyor.

## Masaüstü kabul testleri

- [ ] Eski MasaustuDock kapalıyken, başlangıç Dock ayarı kaydedilir.
- [ ] Dock otomatik gizleme hem açık hem kapalı başlangıçta denenir.
- [ ] Normal pencere, büyütülmüş pencere, küçültme, kapatma ve yeniden boyutlandırma denenir.
- [ ] Erişilebilirlik izni yokken 3 saniyelik mod doğrulanır.
- [ ] İzin verildiğinde desteklenen uygulamada olay modu ve hızlı tepki doğrulanır.
- [ ] İzin geri alındığında yedek moda dönüş doğrulanır.
- [ ] Finder, Safari ve en az bir üçüncü taraf uygulamada denenir.
- [ ] Space değişimi, tam ekran, Masaüstünü Göster ve Mission Control denenir.
- [ ] Birden fazla monitör ve çözünürlük değişimi denenir.
- [ ] Ekran kapanması, uyku/uyanma ve kullanıcı değiştirmede taramanın durup devam etmesi doğrulanır.
- [ ] Normal çıkışta başlangıç Dock ayarının geri geldiği doğrulanır.
- [ ] Aynı uygulamanın ikinci kopyasının ayarı yönetmediği doğrulanır.
- [ ] Aynı koşullarda 10 dakika boşta ve 10 dakika pencere etkileşiminde CPU/enerji etkisi eski sürümle karşılaştırılır.

Enerji sonucu yalnızca ölçümle raporlanmalı; zamanlayıcı sayısındaki düşüş doğrudan pil ömrü artışı olarak sunulmamalıdır.
