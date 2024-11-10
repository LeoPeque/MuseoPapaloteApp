import SwiftUI

struct ContentView: View {
    @State private var showQuiz = false
    @State private var selectedOption: Int? = nil
    @State private var correctAnswerIndex = 1 // Index of "Tyrannosaurus Rex"
    @State private var showCorrectNotification = false

    let options = ["Triceratops", "Tyrannosaurus Rex", "Velociraptor", "Stegosaurus"]
    
    var body: some View {
        ZStack {
            ARViewContainer(showQuiz: $showQuiz)
                .edgesIgnoringSafeArea(.all)
            
            if showQuiz {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Text("Which dinosaur does this skull belong to?")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(0..<options.count, id: \.self) { index in
                            Button(action: {
                                self.selectedOption = index
                                if index == self.correctAnswerIndex {
                                    // Correct answer
                                    self.showCorrectNotification = true
                                }
                            }) {
                                Text(self.options[index])
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(self.buttonBackgroundColor(for: index))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .disabled(selectedOption != nil)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                }
            }
        }
        .alert(isPresented: $showCorrectNotification) {
            Alert(
                title: Text("Correct!"),
                message: Text("You got it right."),
                dismissButton: .default(Text("OK")) {
                    // Reset the quiz state if needed
                    self.resetQuiz()
                }
            )
        }
    }
    
    // Helper function to set button background color
    private func buttonBackgroundColor(for index: Int) -> Color {
        if let selected = selectedOption {
            if selected == index {
                return index == correctAnswerIndex ? Color.green : Color.red
            } else {
                return Color.gray
            }
        } else {
            return Color.blue
        }
    }
    
    // Function to reset the quiz state
    private func resetQuiz() {
        self.selectedOption = nil
        self.showQuiz = false
        // You can also add any additional reset logic here
    }
}
