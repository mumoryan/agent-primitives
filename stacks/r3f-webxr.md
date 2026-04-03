---
# Layer 2: Stack context — R3F/WebXR frontend
# Reusable across any project using this stack
stack: r3f-webxr
---

## [STATIC] Stack Knowledge

### Language
- TypeScript only — never JavaScript
- Strict mode enabled — no implicit any

### Renderer
- React Three Fiber (R3F) — all 3D scene work via JSX components
- @react-three/xr v6 — all XR session, controller, and hand tracking
- @react-three/drei — helpers only, prefer R3F primitives when equivalent
- troika-three-text — all text rendering in VR, never DOM text

### State
- Zustand for world and session state
- No Redux, no Context API for 3D state
- R3F useFrame for per-frame updates — never useEffect for XR state

### Materials (Quest GPU budget)
- MeshBasicMaterial — default choice, unlit, zero GPU cost
- MeshToonMaterial — when stylised shading is needed
- Never MeshStandardMaterial unless spec explicitly requires it
- Never MeshPhysicalMaterial

### Lighting
- Baked lighting preferred — no dynamic shadows
- AmbientLight + HemisphereLight only for real-time
- No real-time GI, no shadow maps unless spec requires and GPU budget confirmed

### Bloom
- Fake bloom: additive emissive halo mesh scaled behind glowing object
- Never UnrealBloomPass or any full-screen post-processing
- Additive blending: THREE.AdditiveBlending on halo mesh material

### DOM
- Never use DOM APIs (document, window, getElementById) inside XR context
- All UI in VR must be 3D — no HTML overlays
- HTML UI only acceptable outside XR session (menus, settings)

### Performance targets (Meta Quest)
- 72fps minimum, 90fps preferred
- Instanced geometry for repeated objects
- Texture atlases where possible
- Particle count: max ~2000
- Draw calls: monitor, keep low
