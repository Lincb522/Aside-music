import SwiftUI

// MARK: - Morph Style Selection View
struct StyleSelectionMorphView: View {
    @ObservedObject var styleManager: StyleManager
    @Binding var isPresented: Bool
    
    @State private var tempSelectedStyle: APIService.StyleTag?
    @State private var selectedTab: String = String(localized: "style_tab_genre")
    
    var namespace: Namespace.ID
    
    private let tabs = [String(localized: "style_tab_genre")]
    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack {
                    ZStack(alignment: .leading) {
                        Text(styleManager.currentStyle == nil ? "Fresh tunes daily" : styleManager.currentStyleName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.clear)
                            .matchedGeometryEffect(id: "filter_text", in: namespace)
                        
                        Text("style_select_title")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.asideTextPrimary.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        AsideIcon(icon: .close, size: 14, color: .asideTextSecondary)
                            .padding(8)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20) 
                .padding(.top, 20)       
                .padding(.bottom, 16)
                
                tabBar
                    .padding(.bottom, 20)
                
                ScrollView(.vertical) {
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
                
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.asideGlassTint)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
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
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring()) { selectedTab = tab }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab)
                                .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundColor(selectedTab == tab ? .asideTextPrimary.opacity(0.85) : .asideTextSecondary)
                            
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.asideIconBackground.opacity(0.85))
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
            tagButton(name: String(localized: "style_default"), isSelected: tempSelectedStyle == nil) {
                tempSelectedStyle = nil
            }
            
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
                .foregroundColor(isSelected ? .white : .asideTextPrimary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.asideIconBackground.opacity(0.85))
                        } else {
                            Capsule()
                                .fill(Color.asideGlassTint)
                                .glassEffect(.regular, in: .capsule)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.asideSeparator, lineWidth: 1)
                                )
                        }
                    }
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
            Text("style_confirm")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.asideIconBackground.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
