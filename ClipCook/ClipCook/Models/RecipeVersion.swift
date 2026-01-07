import Foundation

/// Represents a version of a recipe in the remix history
struct RecipeVersion: Identifiable {
    let id = UUID()
    let title: String
    let recipe: Recipe
    let changedIngredients: Set<String>
    
    init(title: String, recipe: Recipe, changedIngredients: Set<String> = []) {
        self.title = title
        self.recipe = recipe
        self.changedIngredients = changedIngredients
    }
}
