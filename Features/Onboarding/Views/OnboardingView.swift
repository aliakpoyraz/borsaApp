import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @State private var currentTab = 0
    
    var body: some View {
        ZStack {
            // Background gradient based on current tab
            LinearGradient(
                colors: bgColors(for: currentTab),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentTab) {
                    OnboardingPage(
                        imageSystemName: "sparkles",
                        title: "BorsaApp'e Hoş Geldiniz",
                        description: "Finansal dünyayı takip etmenin en modern ve hızlı yoluyla tanışın."
                    )
                    .tag(0)
                    
                    OnboardingPage(
                        imageSystemName: "chart.xyaxis.line",
                        title: "Canlı Piyasalar",
                        description: "Kripto paraları ve BIST hisselerini tek ekrandan anlık verilerle takip edin."
                    )
                    .tag(1)
                    
                    OnboardingPage(
                        imageSystemName: "lock.shield.fill",
                        title: "Güvenli Portföy",
                        description: "Varlıklarınızı ekleyin, gizlilik modu ile değerlerinizi meraklı gözlerden saklayın."
                    )
                    .tag(2)

                    OnboardingPage(
                        imageSystemName: "star.fill",
                        title: "Kişisel Favoriler",
                        description: "Takip etmek istediğiniz varlıkları seçin, kaydırma hareketiyle kolayca yönetin."
                    )
                    .tag(3)

                    OnboardingPage(
                        imageSystemName: "bell.badge.fill",
                        title: "Akıllı Bildirimler",
                        description: "Fiyat hedeflerinizi belirleyin, piyasa fırsatlarını anlık alarmlarla yakalayın."
                    )
                    .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentTab)
                
                // Controls
                HStack {
                    if currentTab < 4 {
                        Button(action: {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }) {
                            Text("Atla")
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.leading, 30)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentTab += 1
                            }
                        }) {
                            HStack {
                                Text("İleri")
                                    .fontWeight(.bold)
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(30)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                        }
                        .padding(.trailing, 30)
                    } else {
                        Button(action: {
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        }) {
                            Text("Hemen Başla")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(30)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func bgColors(for tab: Int) -> [Color] {
        switch tab {
        case 0...4: return [.blue.opacity(0.4), .blue.opacity(0.7)]
        default: return [.blue, .purple]
        }
    }
}

struct OnboardingPage: View {
    let imageSystemName: String
    let title: String
    let description: String
    
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 150, height: 150)
                
                Image(systemName: imageSystemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .scaleEffect(animateIcon ? 1.05 : 0.95)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateIcon)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .default))
                    .kerning(-0.5)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text(description)
                    .font(.system(size: 19, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
            
            Spacer()
            Spacer() // Push pagination upwards
        }
        .onAppear {
            animateIcon = true
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
