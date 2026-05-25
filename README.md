# Voice Bridge — iOS Client

SwiftUI приложение для голосовых звонков с AI.

## Архитектура
- **WebSocket** — подключение к bridge-серверу
- **Dual AVAudioEngine** — отдельные движки для микрофона и плеера
- **VAD на iOS** — определение конца фразы по тишине 1.2 сек

## Настройка
1. Открой `Sources/AudioManager.swift`
2. Замени `serverURL` на IP твоего Мака в локальной сети:
   ```swift
   private let serverURL = URL(string: "ws://192.168.1.5:8765/ws")!
   ```

## Сборка
1. Создай новый проект в Xcode (SwiftUI, iOS 16+)
2. Скопируй файлы из `Sources/` в проект
3. Добавь Info.plist ключи:
   - `Privacy - Microphone Usage Description`
   - `Required background modes` — если нужно фоновое аудио
4. Запусти на устройстве или симуляторе
