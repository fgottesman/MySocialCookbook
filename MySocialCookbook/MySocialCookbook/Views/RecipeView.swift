import SwiftUI
import AVKit

struct RecipeView: View {
    let recipe: Recipe
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Video Player Placeholder
                ZStack {
                    Color.black
                        .aspectRatio(16/9, contentMode: .fit)
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title ?? "Unknown Recipe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: "person.circle.fill")
                        Text(recipe.creatorHandle)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        // Open creator profile
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Ingredients
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(recipe.ingredients ?? ["No ingredients listed"], id: \.self) { ingredient in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                            Text(ingredient)
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(Array((recipe.instructions ?? ["No instructions"]).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .fontWeight(.bold)
                            Text(step)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
