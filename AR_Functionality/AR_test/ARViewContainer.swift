import SwiftUI
import ARKit
import SceneKit
import SpriteKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var showQuiz: Bool

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        sceneView.autoenablesDefaultLighting = true
        
        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Assign sceneView to coordinator
        context.coordinator.sceneView = sceneView
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        // Set up pan gesture recognizer
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(panGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(showQuiz: $showQuiz)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        @Binding var showQuiz: Bool
        
        var sceneView: ARSCNView?
        var skullNode: SCNNode?
        var overlayNode: SCNNode?
        var lastDrawPoint: CGPoint?
        var maskScenes: [SKScene] = []
        
        // Variables to track erased area
        var totalErasedArea: CGFloat = 0.0
        var totalOverlayArea: CGFloat = 0.0
        var overlayRemoved = false
        
        init(showQuiz: Binding<Bool>) {
            _showQuiz = showQuiz
            super.init()
            NotificationCenter.default.addObserver(self,
                selector: #selector(sessionDidBecomeActive),
                name: UIScene.didActivateNotification,
                object: nil)
        }
        
        @objc func sessionDidBecomeActive() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.setupScene()
            }
        }
        
        func setupScene() {
            loadSkullModel()
            createOverlay()
        }
        
        func loadSkullModel() {
            guard let sceneView = sceneView,
                  let skullScene = SCNScene(named: "trex_skull.usdz") else {
                print("Failed to load skull model")
                return
            }
            
            let newSkullNode = skullScene.rootNode.clone()
            skullNode = newSkullNode
            
            // Position and scale the skull
            newSkullNode.scale = SCNVector3(0.1, 0.1, 0.1)
            newSkullNode.position = SCNVector3(0, -0.1, -1.0)
            
            sceneView.scene.rootNode.addChildNode(newSkullNode)
        }
        
        func createOverlay() {
            guard let skullNode = skullNode else { return }
            
            // Get skull dimensions
            let (min, max) = skullNode.boundingBox
            let width = CGFloat(max.x - min.x) * CGFloat(skullNode.scale.x) * 1.5
            let height = CGFloat(max.y - min.y) * CGFloat(skullNode.scale.y) * 1.5
            let depth = CGFloat(max.z - min.z) * CGFloat(skullNode.scale.z) * 1.5
            
            // Create box geometry
            let boxGeometry = SCNBox(
                width: width,
                height: height,
                length: depth,
                chamferRadius: 0
            )
            
            // Load the PNG texture
            guard let overlayTexture = UIImage(named: "overlay_texture.jpg") else {
                print("Failed to load overlay texture")
                return
            }
            
            // Create mask scenes for each face
            let maskSceneSize = CGSize(width: 2048, height: 2048)
            maskScenes = (0..<6).map { _ in
                let scene = SKScene(size: maskSceneSize)
                scene.backgroundColor = .black
                return scene
            }
            
            // Initialize total overlay area and erased area
            totalOverlayArea = CGFloat(maskScenes.count) * maskSceneSize.width * maskSceneSize.height
            totalErasedArea = 0.0
            overlayRemoved = false
            
            // Create materials for each face of the cube
            var materials = [SCNMaterial]()
            for maskScene in maskScenes {
                let material = SCNMaterial()
                material.diffuse.contents = overlayTexture
                material.transparent.contents = maskScene
                material.transparencyMode = .rgbZero
                material.isDoubleSided = true
                // Set rendering order for the material
                material.writesToDepthBuffer = true
                material.readsFromDepthBuffer = true
                materials.append(material)
            }
            
            boxGeometry.materials = materials
            
            // Create and position overlay
            let overlay = SCNNode(geometry: boxGeometry)
            overlayNode = overlay
            
            // Position overlay to encompass the skull
            overlay.position = SCNVector3(
                skullNode.position.x,
                skullNode.position.y,
                skullNode.position.z
            )
            
            // Set the rendering order for the overlay
            overlay.renderingOrder = 1
            
            sceneView?.scene.rootNode.addChildNode(overlay)
        }
        
        func createDustParticles(at position: SCNVector3) -> SCNNode {
            let particleSystem = SCNParticleSystem()
            
            // Configure particle appearance
            particleSystem.particleSize = 0.005
            particleSystem.particleColor = UIColor(red: 139/255, green: 69/255, blue: 19/255, alpha: 0.8)
            particleSystem.particleColorVariation = SCNVector4(0, 0, 0, 0)
            
            // Disable lighting effects
            particleSystem.isLightingEnabled = false
            particleSystem.blendMode = .additive
            
            // Make particles render as flat images and always on top
            particleSystem.sortingMode = .distance
            particleSystem.orientationMode = .free
            particleSystem.fresnelExponent = 0
            
            // Configure particle behavior
            particleSystem.particleLifeSpan = 0.5
            particleSystem.particleVelocity = 0.2
            particleSystem.particleVelocityVariation = 0.1
            particleSystem.spreadingAngle = 180
            particleSystem.acceleration = SCNVector3(0, -0.1, 0)
            
            // Configure emission
            particleSystem.birthRate = 200
            particleSystem.warmupDuration = 0
            particleSystem.emissionDuration = 0.1
            particleSystem.loops = false
            
            // Configure particle physics
            particleSystem.particleMass = 0.01
            
            // Create a node for the particle system
            let particleNode = SCNNode()
            particleNode.addParticleSystem(particleSystem)
            particleNode.position = position
            
            // Make sure particles render on top
            particleNode.renderingOrder = 2
            
            return particleNode
        }
        
        func getWorldPosition(from hitResult: SCNHitTestResult) -> SCNVector3? {
            let worldPosition = SCNVector3(
                hitResult.worldCoordinates.x,
                hitResult.worldCoordinates.y,
                hitResult.worldCoordinates.z
            )
            return worldPosition
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let overlayNode = overlayNode,
                  let view = gesture.view else { return }
            
            let location = gesture.location(in: view)
            
            // Perform hit test
            let hitResults = sceneView?.hitTest(location, options: [:])
            guard let hitResult = hitResults?.first(where: { $0.node == overlayNode }),
                  let materialIndex = hitResult.geometryIndex as Int?,
                  materialIndex < maskScenes.count,
                  let maskScene = maskScenes.element(at: materialIndex) else { return }
            
            // Convert hit location to texture coordinates
            let texCoords = hitResult.textureCoordinates(withMappingChannel: 0)
            let x = texCoords.x * maskScene.size.width
            let y = texCoords.y * maskScene.size.height
            let currentPoint = CGPoint(x: x, y: y)
            
            // Draw reveal effect
            if gesture.state == .began {
                lastDrawPoint = currentPoint
            }
            
            if let lastPoint = lastDrawPoint {
                // Create path between last and current point
                let path = CGMutablePath()
                path.move(to: lastPoint)
                path.addLine(to: currentPoint)
                
                // Create reveal brush
                let brush = SKShapeNode(path: path)
                brush.lineWidth = 100
                brush.strokeColor = .white
                brush.lineCap = .round
                brush.lineJoin = .round
                brush.blendMode = .replace
                
                maskScene.addChild(brush)
                
                // Create and add particles at the world position of the touch
                if let worldPosition = getWorldPosition(from: hitResult) {
                    let particleNode = createDustParticles(at: worldPosition)
                    sceneView?.scene.rootNode.addChildNode(particleNode)
                }
                
                // Compute the area of the brush stroke
                let dx = currentPoint.x - lastPoint.x
                let dy = currentPoint.y - lastPoint.y
                let distance = sqrt(dx * dx + dy * dy)
                let area = distance * brush.lineWidth
                
                totalErasedArea += area
                
                // Check if totalErasedArea >= 70% of totalOverlayArea
                if !overlayRemoved && totalErasedArea >= 0.3 * totalOverlayArea {
                    overlayRemoved = true
                    // Remove overlay and move skull closer
                    let fadeOutAction = SCNAction.fadeOut(duration: 0.5)
                    overlayNode.runAction(fadeOutAction) {
                        self.overlayNode?.removeFromParentNode()
                        self.moveSkullCloser()
                    }
                }
            }
            
            lastDrawPoint = currentPoint
            
            if gesture.state == .ended {
                lastDrawPoint = nil
            }
        }
        
        func moveSkullCloser() {
            guard let skullNode = skullNode else { return }
            let newPosition = SCNVector3(skullNode.position.x, skullNode.position.y, -0.5)
            let moveAction = SCNAction.move(to: newPosition, duration: 1.0) // Ensure duration is Double
            skullNode.runAction(moveAction) {
                // After the skull has moved, show the quiz
                DispatchQueue.main.async {
                    self.showQuiz = true
                }
            }
        }
    }
}

// Extension to safely access array elements using a method
extension Array {
    func element(at index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
