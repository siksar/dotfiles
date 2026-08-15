# GeoClue2 — cihaz konumu (WiFi tabanlı, beacondb.net'e AP taramasıyla sorgu).
# Bu laptopta GPS/GNSS çipi YOK (lsusb/lspci doğrulandı, 09 Ağu) — "konum çipi"
# beklentisinin en yakın karşılığı budur: NetworkManager'ın WiFi taramasını
# kullanan bir ağ-tabanlı konumlama, IP-geo'dan (yalnız ISP'nin kayıtlı IP-blok
# şehri, gerçek konumdan bağımsız olabilir) daha isabetli olması beklenir ama
# yine bir ağ sorgusu — literal "çip" değil.
#
# DURUM (15 Ağu 2026 sürü denetimi): bu alt sistemin HİÇBİR TÜKETİCİSİ YOK.
# Burada bir NM dispatcher'ı vardı; WiFi "up" olayında `geo-weather-sync.service`
# adlı bir kullanıcı servisini başlatıyordu ve o servis repoda HİÇ YAZILMAMIŞTI
# (dosyanın kendi yorumu onu caelestia/default.nix'te sanıyordu; orada da yoktu).
# Çağrı `2>/dev/null || true` ile yutulduğu için hiç ses çıkarmıyordu. Kaldırıldı.
#
# Köprüyü yazmadan önce bilinmesi gereken: hedefi olan hava durumu widget'ı
# home/desktop/caelestia/default.nix'te BİLEREK kapalı (`dashboard.showWeather =
# false`, periyodik ağ isteğini kesmek için; `services.weatherLocation` da o
# yüzden boş). Yani köprüyü yazmak, aynı dosyada bilinçli alınmış bir idle-bütçe
# kararıyla çakışır — önce o karar gözden geçirilmeli, sonra köprü.
#
# Şu anki maliyet: SIFIR. geoclue.service D-Bus aktivasyonlu (upstream modülünde
# `wantedBy` yok, `systemd.packages` ile geliyor) — kimse sormazsa hiç çalışmaz.
# Tek kalıcı maliyet demo agent'tı: `enableDemoAgent` varsayılanı `true` ve
# kullanıcı servisi `default.target`'a bağlı, yani HER GİRİŞTE bir process —
# tüketicisi olmayan bir alt sistem için. Aşağıda kapatıldı.
{ ... }:

{
  services.geoclue2 = {
    enable = true;
    # enableWifi varsayılan zaten true; geoProviderUrl varsayılanı
    # (beacondb.net) API anahtarı gerektirmiyor — dokunulmadı.
    #
    # Demo agent kapalı: geoclue'ya soran bir uygulama olmadığı sürece gereksiz.
    # Bir tüketici eklendiğinde BUNU GERİ AÇMAK ŞART — agent, sistem-dışı
    # istemcilerin yetkilendirilmesini yapan bileşen; o olmadan sorgu reddedilir.
    # Aynı anda `appConfig.<servis-adı> = { isAllowed = true; isSystem = false; }`
    # girdisi de eklenmeli (eski `appConfig.geo-weather-sync` girdisi, karşılığı
    # olmayan bir servisi beyan ettiği için kaldırıldı).
    enableDemoAgent = false;
  };
}
