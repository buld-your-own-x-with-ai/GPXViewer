//
//  ContentView.swift
//  GPSMap
//
//  Created by i on 2025/9/7.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = TrackViewModel()
    @State private var mapType: MapStyle = .standard(elevation: .realistic)
    @State private var showInfo = true
    
    var body: some View {
        ZStack {
            // 3D地图视图
            Map(position: $viewModel.cameraPosition) {
                // 轨迹线
                if !viewModel.trackPoints.isEmpty {
                    // 已经过的轨迹（灰色）
                    if viewModel.currentIndex > 0 {
                        let passedPoints = Array(viewModel.trackPoints[0...viewModel.currentIndex])
                        MapPolyline(coordinates: passedPoints.map { $0.coordinate })
                            .stroke(Color.gray.opacity(0.6), lineWidth: 4)
                    }
                    
                    // 未经过的轨迹（彩色）
                    if viewModel.currentIndex < viewModel.trackPoints.count - 1 {
                        let remainingPoints = Array(viewModel.trackPoints[viewModel.currentIndex...])
                        MapPolyline(coordinates: remainingPoints.map { $0.coordinate })
                            .stroke(.linearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ), lineWidth: 4)
                    }
                    
                    // 起点标记
                    if let first = viewModel.trackPoints.first {
                        Annotation("起点", coordinate: first.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 30, height: 30)
                                Text("起")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    // 终点标记
                    if let last = viewModel.trackPoints.last {
                        Annotation("终点", coordinate: last.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                                Text("终")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    
                    // 当前位置箭头标记
                    if let location = viewModel.currentLocation {
                        Annotation("当前位置", coordinate: location) {
                            Image(systemName: "location.north.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 30, height: 30)
                                )
                                .rotationEffect(.degrees(viewModel.currentHeading))
                                .shadow(radius: 3)
                        }
                    }
                }
            }
            .mapStyle(mapType)
            .edgesIgnoringSafeArea(.all)
            
            // 顶部信息面板
            if viewModel.showTrackInfo {
                VStack {
                    InfoPanel(viewModel: viewModel)
                        .padding()
                    Spacer()
                }
            }
            
            // 底部控制面板
            VStack {
                Spacer()
                ControlPanel(viewModel: viewModel)
                    .padding()
            }
            
            // 右上角按钮组
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        // 收起/展开轨迹信息按钮
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.showTrackInfo.toggle()
                            }
                        }) {
                            Image(systemName: viewModel.showTrackInfo ? "eye.slash" : "eye")
                                .font(.title2)
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        // GPX文件列表按钮
                        Button(action: {
                            viewModel.showingGPXList = true
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.title2)
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        
                        // 地图样式切换按钮
                        Menu {
                            Button("标准") {
                                mapType = .standard(elevation: .realistic)
                            }
                            Button("卫星") {
                                mapType = .imagery(elevation: .realistic)
                            }
                            Button("混合") {
                                mapType = .hybrid(elevation: .realistic)
                            }
                        } label: {
                            Image(systemName: "map")
                                .font(.title2)
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $viewModel.showingGPXList) {
            GPXListView(trackViewModel: viewModel)
        }
        .onOpenURL { url in
            // 处理从其他App分享的GPX文件
            if url.pathExtension.lowercased() == "gpx" {
                let success = viewModel.importGPXFile(from: url)
                if success {
                    print("成功导入GPX文件: \(url.lastPathComponent)")
                } else {
                    print("导入GPX文件失败: \(url.lastPathComponent)")
                }
            }
        }
    }
}

// 信息面板
struct InfoPanel: View {
    @ObservedObject var viewModel: TrackViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("轨迹信息")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Label("深圳市", systemImage: "location.fill")
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            
            HStack {
                Label("时间", systemImage: "clock.fill")
                Text(viewModel.formatTime(for: viewModel.currentIndex))
            }
            .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Label("海拔", systemImage: "mountain.2.fill")
                Text(String(format: "%.1f m", viewModel.currentElevation))
            }
            .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Label("速度", systemImage: "speedometer")
                Text(String(format: "%.1f km/h", viewModel.currentSpeed))
            }
            .foregroundColor(.white.opacity(0.9))
            
            HStack {
                Label("轨迹点", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                Text("\(viewModel.currentIndex + 1) / \(viewModel.trackPoints.count)")
            }
            .foregroundColor(.white.opacity(0.9))
            
            // 坐标系转换开关
            HStack {
                Label("坐标转换", systemImage: "globe.asia.australia.fill")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.enableCoordinateConversion },
                    set: { newValue in
                        viewModel.enableCoordinateConversion = newValue
                        viewModel.loadGPXFile() // 重新加载数据
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
            }
            .foregroundColor(.white.opacity(0.9))
            
            // 保持方向开关
            HStack {
                Label("保持方向", systemImage: "location.north.line")
                Spacer()
                Toggle("", isOn: $viewModel.keepCurrentDirection)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .scaleEffect(0.8)
            }
            .foregroundColor(.white.opacity(0.9))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
    }
}

// 控制面板
struct ControlPanel: View {
    @ObservedObject var viewModel: TrackViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.progress, height: 8)
                }
            }
            .frame(height: 8)
            
            // 控制按钮
            HStack(spacing: 20) {
                // 播放/暂停按钮
                Button(action: {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: viewModel.isPlaying ? [.pink, .red] : [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                
                // 重置按钮
                Button(action: {
                    viewModel.reset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.7))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
                
                Spacer()
                
                // 速度控制
                VStack(alignment: .trailing) {
                    Text("速度: \(Int(viewModel.playbackSpeed))x")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Slider(value: $viewModel.playbackSpeed, in: 1...100, step: 1)
                        .frame(width: 150)
                        .accentColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    ContentView()
}
