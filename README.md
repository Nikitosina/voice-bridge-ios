# Voice Bridge — iOS Client

SwiftUI приложение для голосовых звонков с AI (bridge через WebSocket).

## Быстрый старт

1. **Запусти сервер на Маке:**
   ```bash
   cd voice-bridge
   ./run.sh
   ```
   Сервис слушает порт 8765, принимает WebSocket соединения.

2. **Открой проект в Xcode:**
   ```bash
   open VoiceBridge.xcodeproj
   ```

3. **Убедись, что iPhone и Mac в одной Wi-Fi сети.**

4. **Узнай IP Мака** (в Терминале):
   ```bash
   ifconfig en0 | grep 'inet ' | awk '{print $2}'
   ```

5. **В iOS-приложении** вбей этот IP в поле «IP Мака».

6. **Нажми зелёную кнопку звонка** → говори → слушай ответ.

## Статусы
- 🟠 Соединяю...
- 🔴 Слушаю
- 🔵 Думаю...
- 🟢 Говорю

## Latency
Сейчас ~11 секунд end-to-end (STT + LLM gemma4:31b + TTS). Для MVP это ок, потому что proof-of-concept. Для production нужен более быстрый LLM (llama3.1:8b) — latency упадёт до 3–4 секунд.
