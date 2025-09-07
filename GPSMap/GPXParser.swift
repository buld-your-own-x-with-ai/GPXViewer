//
//  GPXParser.swift
//  GPSMap
//
//  Created by i on 2025/9/7.
//

import Foundation
import CoreLocation

// GPX轨迹点
struct TrackPoint {
    let coordinate: CLLocationCoordinate2D
    let elevation: Double
    let timestamp: Date
}

// 坐标系转换工具
class CoordinateConverter {
    // WGS84转GCJ02（火星坐标系）
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        let a = 6378245.0
        let ee = 0.00669342162296594323
        
        if outOfChina(latitude: latitude, longitude: longitude) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        var dLat = transformLat(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLon(x: longitude - 105.0, y: latitude - 35.0)
        let radLat = latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }
    
    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
    
    private static func outOfChina(latitude: Double, longitude: Double) -> Bool {
        return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271
    }
}

// GPX解析器
class GPXParser: NSObject, XMLParserDelegate {
    private var trackPoints: [TrackPoint] = []
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentElement: String = ""
    private var currentValue: String = ""
    private var enableCoordinateConversion: Bool = true
    
    func parse(url: URL, enableCoordinateConversion: Bool = true) -> [TrackPoint] {
        trackPoints = []
        self.enableCoordinateConversion = enableCoordinateConversion
        
        if let parser = XMLParser(contentsOf: url) {
            parser.delegate = self
            parser.parse()
        }
        
        return trackPoints
    }
    
    func parse(data: Data, enableCoordinateConversion: Bool = true) -> [TrackPoint] {
        trackPoints = []
        self.enableCoordinateConversion = enableCoordinateConversion
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        return trackPoints
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        
        if elementName == "trkpt" {
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "ele":
            currentEle = Double(currentValue) ?? 0
        case "time":
            let formatter = ISO8601DateFormatter()
            currentTime = formatter.date(from: currentValue)
        case "trkpt":
            if let lat = currentLat, let lon = currentLon {
                // 根据设置决定是否进行坐标转换
                let coordinate: CLLocationCoordinate2D
                if enableCoordinateConversion {
                    // 将WGS84坐标转换为GCJ-02坐标系（适用于中国大陆地图）
                    coordinate = CoordinateConverter.wgs84ToGcj02(latitude: lat, longitude: lon)
                } else {
                    // 使用原始WGS84坐标
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                
                let point = TrackPoint(
                    coordinate: coordinate,
                    elevation: currentEle ?? 0,
                    timestamp: currentTime ?? Date()
                )
                trackPoints.append(point)
            }
            // Reset current values
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentTime = nil
        default:
            break
        }
    }
}