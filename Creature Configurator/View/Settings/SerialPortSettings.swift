
import SwiftUI

struct SerialPortSettings: View {
    @AppStorage("programmerSerialPort") private var programmerSerialPort: String = ""
    @AppStorage("programmerSerialBaud") private var programmerSerialBaud: Int = 115200

    // If I give myself a chance to goof up numbers I will 😅
    private let baudRates = [9600, 19200, 38400, 57600, 115200, 230400]

    init() {
    }


    var body: some View {
        VStack {
            Form {

                Section(header: Text("i2c Programmer")) {
                    TextField("Serial Port", text: $programmerSerialPort)
                    Picker("Baud Rate", selection: $programmerSerialBaud) {
                            ForEach(baudRates, id: \.self) { rate in
                                Text("\(rate)").tag(rate)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            Spacer()
        }
    }


}

#Preview {
    SerialPortSettings()
}

