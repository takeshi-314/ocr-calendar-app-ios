//
//  ContentView.swift
//  calendarocr
//
//  Created by TT on 2026/05/07.
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFunctions
import EventKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedDocumentData: Data?
    @State private var selectedMimeType: String = "image/jpeg"
    @State private var selectedFileExtension: String = "jpg"
    @State private var isSelectedPDF: Bool = false
    @State private var isShowingCamera: Bool = false
    @State private var isShowingFileImporter: Bool = false
    @State private var selectedFileName: String = ""
    
    @State private var uploadedPath: String = ""
    @State private var ocrText: String = ""
    @State private var extractedTitle: String = ""
    @State private var extractedDate: String = ""
    @State private var extractedStartTime: String = ""
    @State private var extractedEndTime: String = ""
    @State private var extractedLocation: String = ""
    @State private var extractedItems: [String] = []
    @State private var extractedNotes: String = ""
    @State private var extractedItemsText: String = ""
    @State private var calendarMessage: String = ""
    @State private var isSavingToCalendar: Bool = false
    @State private var aiProcessMessage: String = ""
    @State private var isAiProcessing: Bool = false
    @State private var selectedCalendarDate: Date = Date()
    @State private var selectedStartDateTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var selectedEndDateTime: Date = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("OCRカレンダー")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if isSelectedPDF {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.15))
                        .frame(height: 220)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.orange)

                                Text("PDFファイルを選択中")
                                    .font(.headline)

                                if !selectedFileName.isEmpty {
                                    Text(selectedFileName)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding()
                } else if let selectedImageData,
                          let uiImage = UIImage(data: selectedImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 300)
                        .overlay {
                            Text("まだファイルが選択されていません")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                }
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("写真を選ぶ")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            isShowingCamera = true
                        } label: {
                            Text("カメラで撮る")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.indigo)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Text("ファイルを選ぶ")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !selectedFileName.isEmpty {
                        Text("選択中のファイル：\(selectedFileName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Button {
                    runAiReadingFlow()
                } label: {
                    if isAiProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("AIで読み取る")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(hasSelectedInput() ? Color.orange : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .disabled(!hasSelectedInput() || isAiProcessing)
                .padding(.horizontal)
                
                if !aiProcessMessage.isEmpty {
                    Text(aiProcessMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                if !ocrText.isEmpty {
                    DisclosureGroup("OCR結果を表示") {
                        ScrollView {
                            Text(ocrText)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(maxHeight: 200)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
                
                if !extractedTitle.isEmpty ||
                    !extractedDate.isEmpty ||
                    !extractedStartTime.isEmpty ||
                    !extractedLocation.isEmpty {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("抽出結果の確認・修正")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("予定名")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("例：就職説明会", text: $extractedTitle)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("日付")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "日付を選択",
                                selection: $selectedCalendarDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("開始時刻")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                DatePicker(
                                    "開始",
                                    selection: $selectedStartDateTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("終了時刻")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                DatePicker(
                                    "終了",
                                    selection: $selectedEndDateTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("場所")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("例：湘南工科大学 A棟203", text: $extractedLocation)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("持ち物")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("例：学生証、筆記用具", text: $extractedItemsText)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("補足")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("例：集合は12:50", text: $extractedNotes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                        
                        Button {
                            saveToCalendar()
                        } label: {
                            if isSavingToCalendar {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("カレンダーに登録")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(extractedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .disabled(extractedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingToCalendar)
                        
                        if !calendarMessage.isEmpty {
                            Text(calendarMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.top, 40)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    selectedDocumentData = nil
                    selectedMimeType = "image/jpeg"
                    selectedFileExtension = "jpg"
                    isSelectedPDF = false
                    selectedFileName = ""
                    resetCurrentResult()
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    selectedImageData = data
                    selectedDocumentData = nil
                    selectedMimeType = "image/jpeg"
                    selectedFileExtension = "jpg"
                    isSelectedPDF = false
                    selectedFileName = ""
                    resetCurrentResult()
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImportResult(result)
        }
    }
    private func runAiReadingFlow() {
        guard hasSelectedInput() else {
            aiProcessMessage = "先に画像またはPDFを選択してください。"
            return
        }
        
        isAiProcessing = true
        aiProcessMessage = "画像をアップロード中..."
        ocrText = ""
        calendarMessage = ""
        uploadedPath = ""
        
        extractedTitle = ""
        extractedDate = ""
        extractedStartTime = ""
        extractedEndTime = ""
        extractedLocation = ""
        extractedItems = []
        extractedItemsText = ""
        extractedNotes = ""
        
        Task {
            do {
                let path = try await uploadSelectedFileAsync()
                
                await MainActor.run {
                    uploadedPath = path
                    aiProcessMessage = "OCR実行中..."
                }
                
                let text = try await runOcrAsync(path: path)
                
                await MainActor.run {
                    ocrText = text
                    aiProcessMessage = "予定情報を抽出中..."
                }
                
                let schedule = try await extractScheduleAsync(text: text)
                
                await MainActor.run {
                    applySchedule(schedule)
                    aiProcessMessage = "読み取りが完了しました。内容を確認してください。"
                    isAiProcessing = false
                }
            } catch {
                await MainActor.run {
                    aiProcessMessage = "AI読み取り失敗: \(error.localizedDescription)"
                    isAiProcessing = false
                }
            }
        }
    }
    
    private func hasSelectedInput() -> Bool {
        selectedImageData != nil || selectedDocumentData != nil
    }

    private func saveToCalendar() {
        isSavingToCalendar = true
        calendarMessage = "カレンダー登録準備中..."
        
        Task {
            do {
                let eventStore = EKEventStore()
                
                let granted: Bool
                
                if #available(iOS 17.0, *) {
                    granted = try await eventStore.requestWriteOnlyAccessToEvents()
                } else {
                    granted = try await withCheckedThrowingContinuation { continuation in
                        eventStore.requestAccess(to: .event) { granted, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: granted)
                            }
                        }
                    }
                }
                
                if !granted {
                    await MainActor.run {
                        isSavingToCalendar = false
                        calendarMessage = "カレンダーへのアクセスが許可されませんでした。"
                    }
                    return
                }
                
                let startDate = combineDateAndTime(
                    date: selectedCalendarDate,
                    time: selectedStartDateTime
                )

                let rawEndDate = combineDateAndTime(
                    date: selectedCalendarDate,
                    time: selectedEndDateTime
                )

                let finalEndDate: Date
                if rawEndDate <= startDate {
                    finalEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                } else {
                    finalEndDate = rawEndDate
                }
                
                let event = EKEvent(eventStore: eventStore)
                event.title = extractedTitle.isEmpty ? "予定" : extractedTitle
                event.startDate = startDate
                event.endDate = finalEndDate
                event.location = extractedLocation
                
                var notesParts: [String] = []
                
                if !extractedItemsText.isEmpty {
                    notesParts.append("持ち物：\(extractedItemsText)")
                }
                
                if !extractedNotes.isEmpty {
                    notesParts.append("補足：\(extractedNotes)")
                }
                
                event.notes = notesParts.joined(separator: "\n")
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                try eventStore.save(event, span: .thisEvent)
                
                await MainActor.run {
                    isSavingToCalendar = false
                    calendarMessage = "カレンダーに登録しました。"
                }
            } catch {
                await MainActor.run {
                    isSavingToCalendar = false
                    calendarMessage = "カレンダー登録失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
    private func parseEndTimeFromRange(_ timeText: String, date: Date) -> Date? {
        var text = timeText.trimmingCharacters(in: .whitespacesAndNewlines)

        text = text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "時", with: ":")
            .replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "〜", with: "~")
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "ー", with: "~")
            .replacingOccurrences(of: "−", with: "~")

        guard text.contains("~") else {
            return nil
        }

        let parts = text.split(separator: "~")
        guard parts.count >= 2 else {
            return nil
        }

        let endText = String(parts[1])
        return parseTimeOnDate(endText, date: date)
    }
    private func makeAppError(_ message: String) -> NSError {
        NSError(
            domain: "CalendarOCR",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
    private func parseTimeOnDate(_ timeText: String, date: Date) -> Date? {
        var text = timeText.trimmingCharacters(in: .whitespacesAndNewlines)

        text = text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "時", with: ":")
            .replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "〜", with: "~")
            .replacingOccurrences(of: "～", with: "~")
            .replacingOccurrences(of: "ー", with: "~")
            .replacingOccurrences(of: "−", with: "~")

        if text.contains("~") {
            text = String(text.split(separator: "~").first ?? "")
        }

        let patterns = [
            "H:mm",
            "HH:mm",
            "H"
        ]

        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = pattern

            if let timeOnly = formatter.date(from: text) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)

                return calendar.date(
                    bySettingHour: timeComponents.hour ?? 0,
                    minute: timeComponents.minute ?? 0,
                    second: 0,
                    of: date
                )
            }
        }

        return nil
    }
    private func parseDateOnly(_ dateText: String) -> Date? {
        let cleanDate = dateText.trimmingCharacters(in: .whitespacesAndNewlines)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: cleanDate)
    }
    private func uploadSelectedFileAsync() async throws -> String {
        let uploadData: Data

        if let selectedDocumentData {
            uploadData = selectedDocumentData
        } else if let selectedImageData {
            uploadData = selectedImageData
        } else {
            throw makeAppError("画像またはPDFが選択されていません。")
        }

        let storage = Storage.storage()
        let fileName = UUID().uuidString + ".\(selectedFileExtension)"
        let path = "uploads/\(fileName)"
        let fileRef = storage.reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = selectedMimeType

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            fileRef.putData(uploadData, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: path)
            }
        }
    }
    private func runOcrAsync(path: String) async throws -> String {
        let functions = Functions.functions(region: "asia-northeast1")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            functions.httpsCallable("ocrFromStorage").call([
                "path": path,
                "mimeType": selectedMimeType
            ]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let text = data["text"] as? String else {
                    continuation.resume(throwing: makeAppError("OCRの返答形式が想定と違いました。"))
                    return
                }
                
                continuation.resume(returning: text)
            }
        }
    }
    private func extractScheduleAsync(text: String) async throws -> [String: Any] {
        let functions = Functions.functions(region: "asia-northeast1")
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
            functions.httpsCallable("extractScheduleFromText").call(["text": text]) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = result?.data as? [String: Any],
                      let schedule = data["schedule"] as? [String: Any] else {
                    continuation.resume(throwing: makeAppError("予定抽出の返答形式が想定と違いました。"))
                    return
                }
                
                continuation.resume(returning: schedule)
            }
        }
    }
    private func applySchedule(_ schedule: [String: Any]) {
        extractedTitle = schedule["title"] as? String ?? ""
        extractedDate = schedule["date"] as? String ?? ""
        extractedStartTime = schedule["startTime"] as? String ?? ""
        extractedEndTime = schedule["endTime"] as? String ?? ""
        extractedLocation = schedule["location"] as? String ?? ""
        extractedItems = schedule["items"] as? [String] ?? []
        extractedItemsText = extractedItems.joined(separator: "、")
        extractedNotes = schedule["notes"] as? String ?? ""

        if let parsedDate = parseDateOnly(extractedDate) {
            selectedCalendarDate = parsedDate
        }

        let baseDate = selectedCalendarDate

        if let parsedStart = parseTimeOnDate(extractedStartTime, date: baseDate) {
            selectedStartDateTime = parsedStart
        } else {
            selectedStartDateTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate) ?? baseDate
        }

        if let parsedEnd = parseTimeOnDate(extractedEndTime, date: baseDate) {
            selectedEndDateTime = parsedEnd
        } else if let parsedEndFromRange = parseEndTimeFromRange(extractedStartTime, date: baseDate) {
            selectedEndDateTime = parsedEndFromRange
        } else {
            selectedEndDateTime = Calendar.current.date(byAdding: .hour, value: 1, to: selectedStartDateTime) ?? selectedStartDateTime
        }

        if selectedEndDateTime <= selectedStartDateTime {
            selectedEndDateTime = Calendar.current.date(byAdding: .hour, value: 1, to: selectedStartDateTime) ?? selectedStartDateTime
        }
    }
    private func resetCurrentResult() {
        uploadedPath = ""
        ocrText = ""
        aiProcessMessage = ""
        calendarMessage = ""
        isAiProcessing = false

        extractedTitle = ""
        extractedDate = ""
        extractedStartTime = ""
        extractedEndTime = ""
        extractedLocation = ""
        extractedItems = []
        extractedItemsText = ""
        extractedNotes = ""

        let now = Date()
        selectedCalendarDate = now
        selectedStartDateTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        selectedEndDateTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
    }
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let fileExtension = url.pathExtension.lowercased()

            selectedFileName = url.lastPathComponent

            if fileExtension == "pdf" {
                selectedImageData = nil
                selectedDocumentData = data
                selectedMimeType = "application/pdf"
                selectedFileExtension = "pdf"
                isSelectedPDF = true
            } else {
                selectedImageData = data
                selectedDocumentData = nil
                selectedMimeType = "image/jpeg"
                selectedFileExtension = "jpg"
                isSelectedPDF = false
            }

            resetCurrentResult()
        } catch {
            aiProcessMessage = "ファイル読み込み失敗: \(error.localizedDescription)"
        }
    }
}
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }

            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
#Preview {
    ContentView()
}
