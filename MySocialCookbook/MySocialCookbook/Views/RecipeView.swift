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
                    Text(recipe.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let profile = recipe.profile {
                        HStack {
                            if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                            }
                            
                            Text(profile.username ?? profile.fullName ?? "Unknown Chef")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .onTapGesture {
                            // Open creator profile
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Ingredients
                if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ingredients")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(ingredients, id: \.self) { ingredient in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                Text("\(ingredient.amount) \(ingredient.unit) \(ingredient.name)")
                            }
                        }
                    }
                    .padding(.horizontal)
                    Divider()
                }
                
                // Instructions
                if let instructions = recipe.instructions, !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Instructions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .fontWeight(.bold)
                                Text(step)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
