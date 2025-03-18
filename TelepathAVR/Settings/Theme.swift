//
//  Theme.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 2/2/25.
//

import SwiftUI

struct presetsList: View {
    
    @State private var sliderBaseColor: Color = .white
    @State private var sliderTopColor: Color = .red
    @State private var textColor: Color = .white
    @State private var gradientColors: [Color] = [.gray, .black]
    
    //    @State var width: CGFloat = .zero
    //    @State var height: CGFloat = .zero
    
    @State private var presets: [Preset] = []
    @AppStorage("selectedPresetIndex") private var selectedPresetIndex: Int = 0
    
    @State private var renamed: String = ""
    @State private var pressed: Bool = false
    
    // Focus state
    @FocusState private var renameIsFocused: Bool
    
    let MAX_NUM_PRESETS = 5
    let ANY_CUSTOM_PRESETS = 1
    let MAX_CHARACTERS = 15
    let NUM_DEFAULT_PRESETS = 4
    
    var body: some View {
        
        
        
        VStack (alignment: .leading) {
            Picker("Choose a Preset", selection: $selectedPresetIndex) {
                ForEach(0..<presets.count, id: \.self) { index in
                    Text(presets[index].name)
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 100)
            .onAppear() {
                
                decodePresets()
                if !presets.isEmpty {
                    fetchColorSettings(selectedPresetIndex)
                }
            }
            .onChange(of: presets) {
                if !presets.isEmpty {
                    fetchColorSettings(selectedPresetIndex)
                }
            }
            .onChange(of: selectedPresetIndex) {
                fetchColorSettings(selectedPresetIndex)
                save()
                print("updating the list")
            }
            TextField(presetName, text: $renamed)
                .focused($renameIsFocused)
                .opacity(isCustomPreset ? 1 : 0.5)
                .disabled(!isCustomPreset)
                .onSubmit() {
                    if !renamed.isEmpty {
                        guard presets.indices.contains(selectedPresetIndex) else { return }
                        var currentPreset = presets[selectedPresetIndex]
                        currentPreset.setName(name: renamed)
                        presets.remove(at: selectedPresetIndex)
                        presets.insert(currentPreset, at: selectedPresetIndex)
                        encodePresets()
                    }
                    renamed = ""
                }
                .disableAutocorrection(true)
            ScrollView {
                VStack (alignment: .leading) {
                    ColorPicker("Base Color", selection: $sliderBaseColor)
                    ColorPicker("Top Color", selection: $sliderTopColor)
                    ColorPicker("Text Color", selection: $textColor)
                    
                    Rectangle()
                        .fill(.clear)
                        .frame(height: 10)
                    
                    Group {
                        Text("Background")
                        ColorPicker("Inner Color", selection: $gradientColors[0])
                        ColorPicker("Outer Color", selection: $gradientColors[1])
                    }
                    .padding(.leading, 20)
                        
                    themeButton(.copy) {
                        gradientColors[1] = gradientColors[0]
                    }
                }
                .padding(.trailing, 5)
                .opacity(isCustomPreset ? 1 : 0.5)
                .disabled(!isCustomPreset)
                .onChange( of: sliderBaseColor) {
                    save()
                    updatePresets()
                }
                .onChange(of: sliderTopColor) {
                    save()
                    updatePresets()
                }
                .onChange(of: textColor) {
                    save()
                    updatePresets()
                }
                .onChange( of: gradientColors) {
                    save()
                    updatePresets()
                }
            }
            
            Spacer(minLength: 0)
            
 
            Rectangle()
                .frame(width: 1, height: 2)
                .hidden()
            
            themeButton(.custom) {
                pressed.toggle()
                if customPresetNumber <= MAX_NUM_PRESETS {
                    createCopyPreset(of: selectedPresetIndex)
                    selectedPresetIndex = presets.count - 1
                }
            }
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: pressed)
            
            themeButton(.remove) {
                pressed.toggle()
            outer:
                if customPresetNumber > ANY_CUSTOM_PRESETS {
                    if !isCustomPreset {
                        break outer
                    }
                    presets.remove(at: selectedPresetIndex)
                    selectedPresetIndex = presets.count - 1
                    encodePresets()
                }
            }
        }
    }
    
    func themeButton(_ tab: ThemeTab, onTap: @escaping () -> () = {  } ) -> some View {
        
        Button(action: onTap, label: {
            Text(tab.title)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .frame(maxWidth: CGFloat(160))
                .background(

                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                    .fill(Color(.sideMenuButton))
                )
        })
    }
    
    enum ThemeTab: String, CaseIterable {
        case custom
        case remove
        case copy
        
        var title: String {
            switch self {
            case .custom: return "Custom"
            case .remove: return "Remove"
            case .copy: return "Copy Inner"
            }
        }
        
        static func maxLength() -> Int {
            return (ThemeTab.allCases.max{ $0.title.count < $1.title.count }!).title.count
        }
    }
    
    struct Preset: Codable, Equatable {
        var name: String
        var id: Int
        
        var sliderBaseColor: ColorComponents
        var sliderTopColor: ColorComponents
        var textColor: ColorComponents
        var gradientColors: [ColorComponents]
        
        static func == (lhs: Preset, rhs: Preset) -> Bool {
                return lhs.id == rhs.id
        }
        mutating func setName(name: String) {
            self.name = name
        }
        mutating func setID(id: Int) {
            self.id = id
        }
        mutating func updateColorSettings(
            sliderBaseColor: ColorComponents,
            sliderTopColor: ColorComponents,
            textColor: ColorComponents,
            gradientColors: [ColorComponents]
        ) {
            self.sliderBaseColor = sliderBaseColor
            self.sliderTopColor = sliderTopColor
            self.textColor = textColor
            self.gradientColors = gradientColors
        }
    }
    
    var customPresetNumber: Int {
        return presets.count - NUM_DEFAULT_PRESETS + 1
    }
    var presetName: String {
        if presets.isEmpty {
            return ""
        }
        return presets[selectedPresetIndex].name
    }
    func getCustomPresetNumber() -> Int {
        let customPresets = presets.filter{ $0.id > NUM_DEFAULT_PRESETS }
        var presetNumberArray: [Int] = []
        
        customPresets.forEach() { preset in
            presetNumberArray.append(preset.id - NUM_DEFAULT_PRESETS)
        }
        for i in 1...MAX_NUM_PRESETS {
            if presetNumberArray.contains(i) {
                if let index = presetNumberArray.firstIndex(of: i) {
                    presetNumberArray.remove(at: index)
                }
            }
            else {
                presetNumberArray.append(i)
            }
        }
        if let uniqueMin = presetNumberArray.min() {
            return uniqueMin
        }
        return 0
    }
    
    var isCustomPreset: Bool {
        if presets.isEmpty {
            return true
        }
        return presets[selectedPresetIndex].id > NUM_DEFAULT_PRESETS
    }
    
    func updatePresets() {
        if selectedPresetIndex < NUM_DEFAULT_PRESETS {
            return
        }
        guard presets.indices.contains(selectedPresetIndex) else { return }
        var tempPreset = presets[selectedPresetIndex]
        tempPreset.updateColorSettings(
            sliderBaseColor: ColorComponents(color: sliderBaseColor),
            sliderTopColor: ColorComponents(color: sliderTopColor),
            textColor: ColorComponents(color: textColor),
            gradientColors: gradientColors.map { ColorComponents(color: $0) }

        )
        presets.remove(at: selectedPresetIndex)
        presets.insert(tempPreset, at: selectedPresetIndex)
        encodePresets()
    }
    
    func fetchColorSettings(_ index: Int) {
        if index > presets.count-1 {
            return
        }
        let preset = presets[index]
        sliderBaseColor = preset.sliderBaseColor.toColor()
        sliderTopColor = preset.sliderTopColor.toColor()
        textColor = preset.textColor.toColor()
        gradientColors = preset.gradientColors.map { $0.toColor() }
    }
    
    func decodePresets() {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access Documents directory")
            return
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("ColorPresets.json")
        
        // Check if the file exists and is accessible
        if !fileManager.fileExists(atPath: fileURL.path) {
            print("File not found at path: \(fileURL.path)")
            copyFileToDocuments(fileName: "ColorPresets", fileExtension: "json")
            decodePresets()
            return
        }
        
        // Attempt to read the file
        guard let data = try? Data(contentsOf: fileURL) else {
            print("Unable to read the file, it may be missing or corrupted.")
            copyFileToDocuments(fileName: "ColorPresets", fileExtension: "json")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            let loadedPresets = try decoder.decode([Preset].self, from: data)
            DispatchQueue.main.async {
                presets = loadedPresets  // Ensure we update the UI on the main thread
            }
        } catch {
            print("Error decoding JSON: \(error)")
            return
        }
    }

    func encodePresets() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // Optional for pretty print

        do {
            let jsonData = try encoder.encode(presets)

            // Get the URL for the documents directory
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                fatalError("Unable to access documents directory")
            }

            let fileURL = documentsDirectory.appendingPathComponent("ColorPresets.json")

            // Write the JSON data to the file
            try jsonData.write(to: fileURL, options: .atomic)
            print("Preset saved to: \(fileURL)")
        } catch {
            print("Error encoding or writing to file: \(error)")
        }
    }
    
    func createCopyPreset(of index: Int) {
        var preset: Preset = presets[index]
        preset.setName(name: "Custom \(getCustomPresetNumber())")
        preset.setID(id: getCustomPresetNumber() + NUM_DEFAULT_PRESETS)
        presets.append(preset)
        encodePresets()
    }
    func save() {
        let settings = ColorSettings(
            sliderBaseColor: ColorComponents(color: sliderBaseColor),
            sliderTopColor: ColorComponents(color: sliderTopColor),
            textColor: ColorComponents(color: textColor),
            gradientColors: gradientColors.map { ColorComponents(color: $0) }
        )
        settings.save()
        NotificationCenter.default.post(name: .themeChanged, object: nil)
    }
}

extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}

public struct ColorSettings: Codable {
    var sliderBaseColor: ColorComponents
    var sliderTopColor: ColorComponents
    var textColor: ColorComponents
    var gradientColors: [ColorComponents]

    func save() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            defaults.set(data, forKey: "colorSettings")
        }
    }

    static func load() -> ColorSettings? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "colorSettings") else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(ColorSettings.self, from: data)
    }
}

public struct ColorComponents: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        let components = color.components
        red = components.red
        green = components.green
        blue = components.blue
        alpha = components.alpha
    }
    public static func == (lhs: ColorComponents, rhs: ColorComponents) -> Bool {
        return lhs.red == rhs.red &&
               lhs.green == rhs.green &&
               lhs.blue == rhs.blue &&
               lhs.alpha == rhs.alpha
    }

    func toColor() -> Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}
