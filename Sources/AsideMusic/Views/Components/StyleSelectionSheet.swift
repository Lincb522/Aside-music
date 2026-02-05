import SwiftUI

// MARK: - Morph Style Selection View
struct StyleSelectionMorphView: View {
    @ObservedObject var styleManager: StyleManager
    @Binding var isPresented: Bool
    
    // Internal State
    @State private var tempSelectedStyle: APIService.StyleTag?
    @State private var selectedTab: String = "曲风"
    
    // Matched Geometry
    var namespace: Namespace.ID
    
    // Configuration
    private let tabs = ["曲风"]
    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Expanded Container
            VStack(spacing: 0) {
                // Header (Morph target for the button)
                HStack {
                    ZStack(alignment: .leading) {
                        // 1. Invisible placeholder for smooth morphing (matches source button text exactly)
                        Text(styleManager.currentStyle == nil ? "Fresh tunes daily" : styleManager.currentStyleName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.clear) // Invisible but takes space/morphs
                            .matchedGeometryEffect(id: "filter_text", in: namespace)
                        
                        // 2. Real Title for the Popup (Fades in)
                        Text("选择风格")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.black.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    // Close Button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20) 
                .padding(.top, 20)       
                .padding(.bottom, 16)
                
                // 1. Tab Bar
                tabBar
                    .padding(.bottom, 20)
                
                // 2. Content Area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        if styleManager.isLoadingStyles {
                            ProgressView()
                                .frame(height: 100)
                        } else {
                            styleGrid
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 320)
                
                // 3. Action Bar
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .matchedGeometryEffect(id: "filter_bg", in: namespace)
            )
            .padding(.horizontal, 0)
            .padding(.top, 0)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 140)
        }
        .onAppear {
            tempSelectedStyle = styleManager.currentStyle
        }
    }
    
    // MARK: - Subviews
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring()) { selectedTab = tab }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundColor(selectedTab == tab ? .black.opacity(0.85) : .gray)
                            
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.black.opacity(0.85))
                                    .frame(width: 20, height: 3)
                                    .matchedGeometryEffect(id: "tab_indicator", in: namespace)
                            } else {
                                Capsule().fill(Color.clear).frame(width: 20, height: 3)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var styleGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            // "Default/All" Option (Always first)
            tagButton(name: "默认推荐", isSelected: tempSelectedStyle == nil) {
                tempSelectedStyle = nil
            }
            
            // API Styles
            ForEach(styleManager.availableStyles) { style in
                tagButton(name: style.finalName, isSelected: tempSelectedStyle?.id == style.id) {
                    tempSelectedStyle = style
                }
            }
        }
    }
    
    private func tagButton(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.black.opacity(0.85) : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var actionBar: some View {
        Button(action: {
            styleManager.selectStyle(tempSelectedStyle)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented = false
            }
        }) {
            Text("确认选择")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
