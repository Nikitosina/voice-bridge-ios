import SwiftUI

struct ContentView: View {
    @StateObject private var manager = AudioManager()
    @State private var serverIP: String = UserDefaults.standard.string(forKey: "lastServerIP") ?? "192.168.1.x"
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            if case .idle = manager.state {
                TextField("IP Мака", text: $serverIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .onChange(of: serverIP) { [self] newIP in
                        if let url = URL(string: "ws://\(newIP):8765/ws") {
                            manager.serverURL = url
                            UserDefaults.standard.set(newIP, forKey: "lastServerIP")
                        }
                    }
            }
            
            Text(manager.state.label)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                switch manager.state {
                case .idle, .error:
                    manager.connect()
                case .listening:
                    manager.finishUtterance()
                default:
                    manager.disconnect()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(manager.state.color)
                        .frame(width: 120, height: 120)
                        .shadow(radius: 10)
                    Image(systemName: manager.state == .listening ? "pause.fill" : ((manager.state == .idle || manager.state.isError) ? "phone.fill" : "phone.down.fill"))
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                .scaleEffect(manager.state == .listening ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: manager.state)
            }
            
            Spacer()
            
            Text(manager.state == .idle ? "Отключено" : "Подключено")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            if let url = URL(string: "ws://\(serverIP):8765/ws") {
                manager.serverURL = url
            }
        }
    }
}
