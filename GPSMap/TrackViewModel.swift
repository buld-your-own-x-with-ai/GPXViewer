//
//  TrackViewModel.swift
//  GPSMap
//
//  Created by i on 2025/9/7.
//

import SwiftUI
import MapKit
import Combine
import Foundation

// GPX文件信息结构
struct GPXFileInfo: Identifiable, Codable {
    let id = UUID()
    let fileName: String
    let displayName: String
    let filePath: String
    let dateAdded: Date
    let fileSize: Int64
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: dateAdded)
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// 轨迹视图模型
class TrackViewModel: ObservableObject {
    @Published var trackPoints: [TrackPoint] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 10.0
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var currentElevation: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var progress: Double = 0
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.66, longitude: 114.04),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var enableCoordinateConversion: Bool = true // 默认启用坐标转换
    @Published var currentGPXFileName: String = "20241117_深圳市_90minE"
    @Published var savedGPXFiles: [GPXFileInfo] = []
    @Published var showingGPXList: Bool = false
    @Published var keepCurrentDirection: Bool = false // 保持当前方向，不自动旋转
    @Published var showTrackInfo: Bool = true // 显示轨迹信息面板
    @Published var currentHeading: Double = 0 // 当前运动方向（度数）
    
    private var timer: Timer?
    private let parser = GPXParser()
    private let documentsDirectory: URL
    
    init() {
        // 获取文档目录
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 创建GPX文件夹
        createGPXDirectoryIfNeeded()
        
        // 加载已保存的GPX文件列表
        loadSavedGPXFiles()
        
        // 加载默认GPX文件
        loadGPXFile()
    }
    
    func loadGPXFile() {
        // 加载默认GPX文件
        if let url = Bundle.main.url(forResource: currentGPXFileName, withExtension: "gpx") {
            trackPoints = parser.parse(url: url, enableCoordinateConversion: enableCoordinateConversion)
        } else {
            // 如果Bundle中没有，尝试从项目目录加载
            let fileURL = URL(fileURLWithPath: "/Users/i/Code/Build_Your_Onw_X_With_AI/GPSMap/GPSMap/\(currentGPXFileName).gpx")
            if let data = try? Data(contentsOf: fileURL) {
                trackPoints = parser.parse(data: data, enableCoordinateConversion: enableCoordinateConversion)
            }
        }
        
        updateMapRegionAndCamera()
    }
    
    // 从指定URL加载GPX文件
    func loadGPXFile(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            trackPoints = parser.parse(data: data, enableCoordinateConversion: enableCoordinateConversion)
            currentGPXFileName = url.deletingPathExtension().lastPathComponent
            updateMapRegionAndCamera()
        } catch {
            print("Error loading GPX file from URL: \(error)")
        }
    }
    
    // 更新地图区域和相机位置
    private func updateMapRegionAndCamera() {
        
        if !trackPoints.isEmpty {
            currentLocation = trackPoints[0].coordinate
            updateMapRegion()
        }
    }
    
    func play() {
        isPlaying = true
        startAnimation()
    }
    
    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        currentIndex = 0
        progress = 0
        if !trackPoints.isEmpty {
            currentLocation = trackPoints[0].coordinate
            updateMapRegion()
        }
    }
    
    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }
    
    private func updatePosition() {
        guard !trackPoints.isEmpty else { return }
        
        if currentIndex >= trackPoints.count - 1 {
            pause()
            return
        }
        
        let increment = Int(playbackSpeed)
        currentIndex = min(currentIndex + increment, trackPoints.count - 1)
        
        let point = trackPoints[currentIndex]
        currentLocation = point.coordinate
        currentElevation = point.elevation
        
        // 计算速度
        if currentIndex > 0 {
            let prevPoint = trackPoints[currentIndex - 1]
            let distance = calculateDistance(from: prevPoint.coordinate, to: point.coordinate)
            let timeDiff = point.timestamp.timeIntervalSince(prevPoint.timestamp)
            if timeDiff > 0 {
                currentSpeed = (distance / timeDiff) * 3.6 // km/h
            }
        }
        
        // 更新进度
        progress = Double(currentIndex) / Double(trackPoints.count - 1)
        
        // 更新地图视角
        updateCameraPosition()
    }
    
    private func updateMapRegion() {
        guard let location = currentLocation else { return }
        mapRegion = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
    
    private func updateCameraPosition() {
        guard let location = currentLocation else { return }
        
        // 计算当前运动方向
        if currentIndex > 0 {
            currentHeading = calculateHeading()
        }
        
        // 创建3D视角
        let heading = keepCurrentDirection ? 0 : currentHeading
        
        cameraPosition = .camera(
            MapCamera(
                centerCoordinate: location,
                distance: 800, // 相机距离
                heading: heading, // 方向：如果保持当前方向则为0，否则根据运动方向计算
                pitch: 60     // 倾斜角度
            )
        )
    }
    
    private func calculateHeading() -> Double {
        guard currentIndex > 0 && currentIndex < trackPoints.count else { return 0 }
        
        let from = trackPoints[currentIndex - 1].coordinate
        let to = trackPoints[currentIndex].coordinate
        
        let deltaLon = to.longitude - from.longitude
        let y = sin(deltaLon * .pi / 180) * cos(to.latitude * .pi / 180)
        let x = cos(from.latitude * .pi / 180) * sin(to.latitude * .pi / 180) -
                sin(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180) * cos(deltaLon * .pi / 180)
        
        let heading = atan2(y, x) * 180 / .pi
        return heading
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }
    
    func formatTime(for index: Int) -> String {
        guard index < trackPoints.count else { return "--:--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: trackPoints[index].timestamp)
    }
    
    // MARK: - GPX文件管理功能
    
    // 创建GPX文件夹
    private func createGPXDirectoryIfNeeded() {
        let gpxDirectory = documentsDirectory.appendingPathComponent("GPXFiles")
        if !FileManager.default.fileExists(atPath: gpxDirectory.path) {
            try? FileManager.default.createDirectory(at: gpxDirectory, withIntermediateDirectories: true)
        }
    }
    
    // 保存GPX文件到本地
    func saveGPXFile(from sourceURL: URL, withName customName: String? = nil) -> Bool {
        do {
            let gpxDirectory = documentsDirectory.appendingPathComponent("GPXFiles")
            
            // 生成文件名
            let originalFileName = sourceURL.deletingPathExtension().lastPathComponent
            let displayName = customName ?? originalFileName
            let fileName = "\(UUID().uuidString).gpx"
            let destinationURL = gpxDirectory.appendingPathComponent(fileName)
            
            // 复制文件
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // 获取文件大小
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // 创建文件信息
            let fileInfo = GPXFileInfo(
                fileName: fileName,
                displayName: displayName,
                filePath: destinationURL.path,
                dateAdded: Date(),
                fileSize: fileSize
            )
            
            // 添加到列表并保存
            savedGPXFiles.append(fileInfo)
            savePersistentGPXList()
            
            return true
        } catch {
            print("保存GPX文件失败: \(error)")
            return false
        }
    }
    
    // 从URL导入GPX文件（用于处理其他App分享的文件）
    func importGPXFile(from url: URL) -> Bool {
        // 确保可以访问文件
        guard url.startAccessingSecurityScopedResource() else {
            print("无法访问安全范围资源")
            return false
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // 保存文件
        let success = saveGPXFile(from: url)
        
        if success {
            // 立即加载这个新导入的文件
            loadGPXFile(from: url)
        }
        
        return success
    }
    
    // 加载已保存的GPX文件列表
    func loadSavedGPXFiles() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "SavedGPXFiles"),
           let files = try? JSONDecoder().decode([GPXFileInfo].self, from: data) {
            // 验证文件是否仍然存在
            savedGPXFiles = files.filter { fileInfo in
                FileManager.default.fileExists(atPath: fileInfo.filePath)
            }
            
            // 如果有文件被删除，更新持久化数据
            if savedGPXFiles.count != files.count {
                savePersistentGPXList()
            }
        }
    }
    
    // 保存GPX文件列表到UserDefaults
    private func savePersistentGPXList() {
        let userDefaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(savedGPXFiles) {
            userDefaults.set(data, forKey: "SavedGPXFiles")
        }
    }
    
    // 删除GPX文件
    func deleteGPXFile(_ fileInfo: GPXFileInfo) {
        // 从文件系统删除
        try? FileManager.default.removeItem(atPath: fileInfo.filePath)
        
        // 从列表中移除
        savedGPXFiles.removeAll { $0.id == fileInfo.id }
        
        // 更新持久化数据
        savePersistentGPXList()
    }
    
    // 加载选中的GPX文件
    func loadSelectedGPXFile(_ fileInfo: GPXFileInfo) {
        let fileURL = URL(fileURLWithPath: fileInfo.filePath)
        loadGPXFile(from: fileURL)
        currentGPXFileName = fileInfo.displayName
        showingGPXList = false
    }
    
    // 重命名GPX文件
    func renameGPXFile(_ fileInfo: GPXFileInfo, newName: String) {
        if let index = savedGPXFiles.firstIndex(where: { $0.id == fileInfo.id }) {
            let updatedFileInfo = GPXFileInfo(
                fileName: fileInfo.fileName,
                displayName: newName,
                filePath: fileInfo.filePath,
                dateAdded: fileInfo.dateAdded,
                fileSize: fileInfo.fileSize
            )
            savedGPXFiles[index] = updatedFileInfo
            savePersistentGPXList()
            
            // 如果当前加载的是这个文件，更新显示名称
            if currentGPXFileName == fileInfo.displayName {
                currentGPXFileName = newName
            }
        }
    }
    
    // 获取GPX文件统计信息
    var gpxFilesCount: Int {
        savedGPXFiles.count
    }
    
    var totalGPXFilesSize: String {
        let totalSize = savedGPXFiles.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}