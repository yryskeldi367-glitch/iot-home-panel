# iot-home-panel — панель «Умный дом»

Мобильное и десктопное приложение-компаньон для системы умного дома:
живые показания датчиков, переключение реле, история телеметрии.

Один код — три платформы: **Android (APK)**, **Windows (EXE)** и, при желании,
iOS/macOS/Linux тем же кодом. Интерфейс — Flutter **Cupertino** в стиле iOS:
стеклянные полупрозрачные карточки с размытием (glassmorphism), крупные
заголовки, скруглённые углы, плавные переходы; светлая и тёмная тема
включаются автоматически по настройкам системы.

## Возможности

| | |
|---|---|
| 🌡 **Обзор** | температура, влажность, движение, газ (ppm), протечка — стеклянные карточки в реальном времени + график температуры гостиной |
| 💡 **Реле** | свет, вытяжка, кондиционер и т.д. — переключатели отправляют команду `smarthome/cmd/<id>`; фактическое состояние приходит в ответ и подсвечивает переключатель |
| 📈 **История** | выбор метрики (°C / % / ppm), линейный график (CustomPainter, без внешних пакетов) и лента событий (тревоги газа и протечки) |
| ⚙️ **Настройки** | демо-режим или подключение к MQTT-брокеру (адрес + порт) |

**Данные хранятся локально** (JSON-файлы в каталоге приложения), регистрации
нет, интернет не нужен. Демо-режим — встроенный генератор данных: приложение
полностью работает офлайн «из коробки».

## Два режима работы

1. **Демо-режим** (по умолчанию). Встроенный симулятор генерирует те же модели,
   что и настольный проект `iot22_smarthome`: суточный ход температуры,
   дрейф AR(1), движение по расписанию дня, газовое событие с фазами
   «рост → плато → спад», редкая протечка. Подходит для демонстрации без
   какой-либо инфраструктуры.
2. **Реальный брокер MQTT.** Подключение к любому брокеру (например,
   Mosquitto из настольного проекта). Приложение понимает ту же схему топиков:

```
smarthome/<комната>/<id>/telemetry   ← телеметрия (JSON)
smarthome/<комната>/<id>/status      ← online/offline (LWT, retained)
smarthome/cmd/<id>                   ← команды реле (панель публикует)
smarthome/system/alarm               ← тревоги
```

Переключатель на вкладке «Реле» публикует
`{"cmd":"set","state":"on","by":"panel"}` — реле подтверждает состояние
retained-пакетом, и переключатель показывает фактическое положение.

## Скриншоты

Скриншоты вкладок (обзор / реле / история / настройки) — в папке
`screenshots/` репозитория и в описании
[Releases](https://github.com/yryskeldi367-glitch/iot-home-panel/releases).

## Как установить (готовые файлы)

1. Откройте [Releases](https://github.com/yryskeldi367-glitch/iot-home-panel/releases).
2. Скачайте нужный файл:
   - `iot-home-panel-android.apk` — установка на Android
     (разрешите «установка из неизвестных источников»);
   - `home-panel-windows.zip` — распаковать, запустить `home_panel.exe`.
3. Приложение стартует в демо-режиме — уже работает.

## Как собрать из исходников

Нужен Flutter 3.24.x (stable) и платформенный тулчейн
(Android SDK для APK, Visual Studio 2022 «Desktop development with C++» для Windows).

```bash
git clone https://github.com/yryskeldi367-glitch/iot-home-panel.git
cd iot-home-panel
flutter pub get
flutter analyze          # 0 ошибок
flutter test             # smoke-тест

flutter build apk --release          # -> build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release      # -> build/windows/x64/runner/Release/
```

## CI/CD

* [`build.yml`](.github/workflows/build.yml) — на каждый push: `flutter analyze`
  + `flutter test` + сборка **APK** (ubuntu) и **EXE** (windows), результаты — в артефактах.
* [`release.yml`](.github/workflows/release.yml) — на тег `v*`: обе сборки +
  автоматическая публикация в **GitHub Releases** (`iot-home-panel-android.apk`,
  `home-panel-windows.zip`).

Чтобы выпустить версию: `git tag v1.0.1 && git push origin v1.0.1` — релиз соберётся сам.

## Структура кода

```
lib/
├── main.dart           # CupertinoApp, 4 вкладки, тема по системе
├── app_state.dart      # ChangeNotifier: приём данных, серии, события, хранение
├── models.dart         # Reading, MetricPoint (JSON-конверт)
├── simulator.dart      # демо-генератор (AR(1), расписания, автомат фаз газа)
├── mqtt_service.dart   # обёртка mqtt_client: подписка smarthome/#, публикация
├── store.dart          # локальные JSON-файлы (settings/history)
└── ui/
    ├── widgets.dart    # GlassCard, StatusPill, LineChart (CustomPainter)
    └── tabs.dart       # обзор / реле / история / настройки
```

## Совместимость

* Android 6+ (APK);
* Windows 10/11 x64 (EXE, Visual Studio runtime);
* iOS/macOS/Linux — тот же Dart-код, платформенные папки добавляются
  командой `flutter create --platforms=ios .`.
