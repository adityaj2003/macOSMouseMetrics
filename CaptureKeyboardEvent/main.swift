import Foundation
import Quartz
import Cocoa
import CoreGraphics.CGEvent
import MongoSwiftSync


var lastMousePosition: CGPoint?
var dist = 0.0;
var numRight = 0;
var numLeft = 0;
var keyPresses = 0;



func trackMouseMovement(currentPosition: CGPoint) {
    if let lastPosition = lastMousePosition {
        let dx = currentPosition.x - lastPosition.x
        let dy = currentPosition.y - lastPosition.y
        let distance = sqrt(dx*dx + dy*dy)
        dist += (13.3/1664) * 0.084 * Double(distance);
//        print("distance travelled \(dist)")
        
    }
    lastMousePosition = currentPosition
}

func mouseEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    switch type {
    case .leftMouseDown:
        print(event.location)
        numLeft+=1;
        print("Left click detected")
    case .rightMouseDown:
        numRight+=1;
//        print("Right click detected")
    case .keyDown:
        keyPresses+=1;
//        print("Key press detected")
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
        trackMouseMovement(currentPosition: event.location)
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}


func sendStatsToAPI(distance: Double, numRight: Int, numLeft: Int, keyPresses: Int) {
    let client = try! MongoClient("mongodb+srv://adityaj2003:@cluster0.dcg6idk.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0")
        let database = client.db("PersonalWebsite")
        let collection = try database.collection("metrics")

    let stats: BSONDocument = [
        "distance": .double(distance),
                "numRight": .int32(Int32(numRight)),
                "numLeft": .int32(Int32(numLeft)),
                "keyPresses": .int32(Int32(keyPresses)),
                "timestamp": .datetime(Date())
        ]

        do {
            let documentCount = try collection.countDocuments()
            if documentCount >= 288 {
                let filter: BSONDocument = ["timestamp": ["$lt": .datetime(Date())]]
                let options = FindOneAndDeleteOptions(sort: ["timestamp": 1])
                let oldestDocument = try collection.findOneAndDelete(filter, options: options)
                if oldestDocument == nil {
                    print("No document found to delete")
                }
            }
            try collection.insertOne(stats)
        } catch {
            print("Error sending stats: \(error)")
        }
}

// Simulate sending data every 5 minutes
Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
    // Replace these with your actual data
    sendStatsToAPI(distance: dist, numRight: numRight, numLeft: numLeft, keyPresses: keyPresses);
    dist = 0.0;
    numRight = 0;
    numLeft = 0;
    keyPresses = 0;
}



// Function to send the keycode to the API

let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                             (1 << CGEventType.rightMouseDown.rawValue) |
                             (1 << CGEventType.otherMouseDown.rawValue) |
                             (1 << CGEventType.keyDown.rawValue) |
                             (1 << CGEventType.mouseMoved.rawValue) |
                             (1 << CGEventType.leftMouseDragged.rawValue) |
                             (1 << CGEventType.rightMouseDragged.rawValue) |
(1 << CGEventType.otherMouseDragged.rawValue);

guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: mouseEventCallback,
    userInfo: nil
) else {
    print("Failed to create event tap")
    exit(1)
}
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

// Add the source to the current run loop
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

// Enable the event tap
CGEvent.tapEnable(tap: eventTap, enable: true)

// Run the loop
CFRunLoopRun()

