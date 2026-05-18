import SwiftUI
import CoreMotion

//struct ParallaxModifier: ViewModifier {
//    var intensity: Double = 8
//
//    @State private var pitch: Double = 0
//    @State private var roll:  Double = 0
//
//    private let motion = CMMotionManager()
//    private let queue  = OperationQueue()
//
//    func body(content: Content) -> some View {
//        content
//            .rotation3DEffect(.degrees(pitch * intensity), axis: (x: 1, y: 0, z: 0))
//            .rotation3DEffect(.degrees(roll  * intensity), axis: (x: 0, y: 1, z: 0))
//            .onAppear {
//                guard motion.isDeviceMotionAvailable else { return }
//                queue.maxConcurrentOperationCount = 1
//                queue.qualityOfService = .userInteractive
//                motion.deviceMotionUpdateInterval = 1.0 / 30.0
//                motion.startDeviceMotionUpdates(to: queue) { data, _ in
//                    guard let attitude = data?.attitude else { return }
//                    let p = attitude.pitch
//                    let r = attitude.roll
//                    DispatchQueue.main.async {
//                        withAnimation {
//                            pitch = p
//                            roll  = r
//                        }
//                    }
//                }
//            }
//            .onDisappear { motion.stopDeviceMotionUpdates() }
//    }
//}

struct AccelerationModifier: ViewModifier {
    var intensity: Double = 8
    
    @State private var x: Double = 0
    @State private var y:  Double = 0
    
    private let motion = CMMotionManager()
    private let queue  = OperationQueue()
    
    func body(content: Content) -> some View {
        content
            .offset(
                x: x,
                y: y
            )
            .onAppear {
                guard motion.isDeviceMotionAvailable else { return }
                queue.maxConcurrentOperationCount = 1
                queue.qualityOfService = .userInteractive
                motion.deviceMotionUpdateInterval = 1.0 / 30.0
                motion.startDeviceMotionUpdates(to: queue) { data, _ in
                    guard let uA = data?.userAcceleration else { return }
                    let xx = uA.x
                    let yy = uA.y
                    DispatchQueue.main.async {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7)) {
                            x = xx
                            y = yy
                        }
                    }
                }
            }
            .onDisappear { motion.stopDeviceMotionUpdates() }
    }
}





extension View {
    func parallax(intensity: Double = 8) -> some View {
        modifier(AccelerationModifier(intensity: intensity))
    }
}
