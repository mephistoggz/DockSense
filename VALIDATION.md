# Doğrulama durumu

Bu dosya yalnızca gerçekten tamamlanan kontrolleri kaydeder.

## Tamamlanan kontroller

- Apple Command Line Tools kurulduktan sonra `sh tests/run.sh` **bu Mac üzerinde de geçti**: 16 politika doğrulaması, altı derleme güvenliği senaryosu, universal derleme ve imza doğrulaması.
- Yerel derlemede bulut eşitlemesinin `.app` klasörüne eklediği FinderInfo imzalamayı engelliyordu. Paket sistemin geçici klasöründe oluşturulup imzalandıktan sonra çıktı klasörüne taşınacak şekilde düzeltildi. Güvenlik testi geçici klasörün hata durumlarında temizlendiğini de kontrol ediyor.
- Sistem Ayarları'nda iki DockSense kaydı görüldü: biri izinli, biri izinsiz. Kullanıcı izin verdiğini doğruladı; komut satırı teşhisi ile çalışan GUI kopyasının izin atfı aynı kabul edilmemelidir.
- GitHub Actions çalışması [43980815097](https://github.com/mephistoggz/DockSense/actions/runs/43980815097), kaynak commit `a4e845d722edecc1acee431ad5d70b2e4b89ff8b`: **başarılı**. 16 C politika doğrulaması, altı derleme güvenliği senaryosu, Intel/Apple Silicon derlemesi, paket/imza doğrulaması ve ZIP üretimi geçti.
- İlk CI çalışması, `lipo` parametre sırasındaki hatayı ortaya çıkardı. Dosya yolu `-verify_arch` önüne taşındı; sahte araç testi de bu sıralamayı kontrol edecek şekilde güçlendirildi.
- İndirilen CI arşivinin SHA-256 özeti GitHub çıktısıyla eşleşti: `63859b0f37702568c0498998c438f4535ecf89d0cd7586c792433064b3288495`.
- Yerel `codesign --verify --strict` kontrolü geçti. `file` çıktısında hem `x86_64` hem `arm64` doğrulandı.
- Mac üzerindeki `--diagnose` sonucu: `Dock API: available`, `Accessibility: not granted`, `Window enumeration: ok`, `Visible windows: 4`.
- Uygulamanın açık olduğu süreç listesinde doğrulandı. Yaklaşık 92 saniyelik çalışma sonunda toplam CPU süresi 1,32 saniyeydi; anlık CPU %0,0 idi. Bu tek gözlem karşılaştırmalı enerji veya pil ömrü ölçümü değildir.
- İndirilen ad-hoc imzalı paket ilk açılışta macOS güvenlik politikasına takıldı. Daha sonraki açılış ve teşhis başarılı oldu. Developer ID/notarizasyon henüz yoktur.
- `sh -n build.sh`, `sh -n tests/run.sh`, `sh -n tests/build_safety.sh`: kabuk sözdizimi kontrolleri geçti.
- `plutil -lint Info.plist`: uygulama ayar dosyası geçerli.
- `sh tests/build_safety.sh`: gerçek derleme betiği, sahte derleyici/imzalayıcı ile altı senaryoda çalıştırıldı. Eksik derleyici, derleme hatası, mimari kontrol hatası, imzalama hatası ve imza doğrulama hatasında önceki uygulama korundu; başarılı senaryoda yeni paket yerini aldı. Geçici derleme klasörleri hata yollarında temizlendi.
- `sh build.sh`: gerçek derleme denendi; Apple Command Line Tools bulunmadığı için beklenen açıklamayla durdu. Bu sonuç derlemenin geçtiği anlamına gelmez.
- Kaynak incelemesinde Dock görünürlüğünden kaynaklanabilecek ekran bildirimlerinin yeniden ölçüm döngüsü başlatmaması için ekran kimliği/konumu/ölçeği kontrolü eklendi. Bu korumanın masaüstünde doğrulanması hâlâ gerekiyor.

## Henüz tamamlanmayanlar

- Pencere büyütme/küçültme, çoklu ekran, Space/uyku senaryoları ve Erişilebilirlik bildirimlerinin alınması.
- Eski sürümle kontrollü CPU/enerji karşılaştırması ve pil ölçümü.
- Depo GitHub'a özel olarak yüklendi; genel dağıtıma hazır, tam davranış testli bir sürüm olarak sunulmadı.

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
