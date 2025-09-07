//
//  GPXListView.swift
//  GPSMap
//
//  Created by i on 2025/9/7.
//

import SwiftUI

struct GPXListView: View {
    @ObservedObject var trackViewModel: TrackViewModel
    @State private var showingRenameAlert = false
    @State private var selectedFileForRename: GPXFileInfo?
    @State private var newFileName = ""
    @State private var showingDeleteAlert = false
    @State private var selectedFileForDelete: GPXFileInfo?
    @State private var showingDocumentPicker = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 统计信息
                if !trackViewModel.savedGPXFiles.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已保存文件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(trackViewModel.gpxFilesCount) 个文件")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("总大小")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trackViewModel.totalGPXFilesSize)
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // GPX文件列表
                if trackViewModel.savedGPXFiles.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无GPX文件")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("通过其他应用分享GPX文件到此应用\n或导入GPX文件来开始使用")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(trackViewModel.savedGPXFiles.sorted(by: { $0.dateAdded > $1.dateAdded })) { fileInfo in
                            GPXFileRow(
                                fileInfo: fileInfo,
                                isCurrentFile: trackViewModel.currentGPXFileName == fileInfo.displayName,
                                onSelect: {
                                    trackViewModel.loadSelectedGPXFile(fileInfo)
                                },
                                onRename: {
                                    selectedFileForRename = fileInfo
                                    newFileName = fileInfo.displayName
                                    showingRenameAlert = true
                                },
                                onDelete: {
                                    selectedFileForDelete = fileInfo
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("GPX文件")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        trackViewModel.showingGPXList = false
                    }
                }
            }
        }
        .alert("重命名文件", isPresented: $showingRenameAlert) {
            TextField("文件名", text: $newFileName)
            Button("取消", role: .cancel) { }
            Button("确定") {
                if let fileInfo = selectedFileForRename, !newFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    trackViewModel.renameGPXFile(fileInfo, newName: newFileName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } message: {
            Text("请输入新的文件名")
        }
        .alert("删除文件", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let fileInfo = selectedFileForDelete {
                    trackViewModel.deleteGPXFile(fileInfo)
                }
            }
        } message: {
            if let fileInfo = selectedFileForDelete {
                Text("确定要删除文件 \"\(fileInfo.displayName)\" 吗？此操作无法撤销。")
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                let success = trackViewModel.importGPXFile(from: url)
                if success {
                    print("成功导入GPX文件: \(url.lastPathComponent)")
                } else {
                    print("导入GPX文件失败: \(url.lastPathComponent)")
                }
            }
        }
    }
}

struct GPXFileRow: View {
    let fileInfo: GPXFileInfo
    let isCurrentFile: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fileInfo.displayName)
                        .font(.headline)
                        .foregroundColor(isCurrentFile ? .blue : .primary)
                    
                    if isCurrentFile {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                HStack {
                    Text(fileInfo.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(fileInfo.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: onSelect) {
                    Label("加载", systemImage: "play.circle")
                }
                
                Button(action: onRename) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Button(action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    GPXListView(trackViewModel: TrackViewModel())
}