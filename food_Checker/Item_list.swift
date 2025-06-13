//
//  Item_list.swift
//  food_Checker
//
//  Created by Jonas Kilian on 08.05.25.
//
import SwiftUI
import CoreData

// MARK: - Core Data Singleton

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "ShoppingModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("❌ Fehler beim Laden des Core Data Stores: \(error)")
            } else {
                print("✅ Core Data geladen aus: \(description.url?.absoluteString ?? "Unbekannt")")
                print("✅ Entitäten: \(self.container.managedObjectModel.entities.map { $0.name ?? "?" })")
            }
        }
    }
}

// MARK: - Core Data Modellklasse

@objc(ShoppingItem)
public class ShoppingItem: NSManagedObject {}

extension ShoppingItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingItem> {
        return NSFetchRequest<ShoppingItem>(entityName: "ShoppingItem")
    }

    @NSManaged public var name: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var quantity: Float
    @NSManaged public var unit: String?
}

extension ShoppingItem: Identifiable {}

// MARK: - ViewModel

class ShoppingListViewModel: ObservableObject {
    @Published var items: [ShoppingItem] = []

    private let context = PersistenceController.shared.container.viewContext

    init() {
        fetchItems()
    }

    func fetchItems() {
        let request: NSFetchRequest<ShoppingItem> = ShoppingItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ShoppingItem.timestamp, ascending: true)]
        do {
            items = try context.fetch(request)
        } catch {
            print("❌ Fehler beim Laden: \(error)")
        }
    }

    func addItem(name: String, quantity: Float, unit: String) {
        let newItem = ShoppingItem(context: context)
        newItem.name = name
        newItem.timestamp = Date()
        newItem.quantity = quantity
        newItem.unit = unit

        saveContext()
        fetchItems()
    }
    func deleteItem(at offsets: IndexSet) {
        offsets.forEach { index in
            let item = items[index]
            context.delete(item)
        }
        saveContext()
        fetchItems()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("❌ Fehler beim Speichern: \(error)")
        }
    }
}

// MARK: - SwiftUI View

struct ThirdView: View {
    
    let units = ["Stück", "kg", "g", "l", "ml"]
    
    
    @StateObject var viewModel = ShoppingListViewModel()
    @State private var newItemName = ""
    @State private var newItemQuantity = ""
    @State private var newItemUnit = "Stück"
    
    func formattedQuantity(_ quantity: Float) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity)) // z. B. 1.0 → "1"
        } else {
            return String(format: "%.1f", quantity) // z. B. 1.25 → "1.25"
        }
    }
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Artikel", text: $newItemName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Menge", text: $newItemQuantity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                    
                    Picker("Einheit", selection: $newItemUnit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit)
                        }
                    }
                    Button("Hinzufügen") {
                        let cleanedQuantity = newItemQuantity.replacingOccurrences(of: ",", with: ".")
                        guard !newItemName.isEmpty,
                              let quantity = Float(cleanedQuantity),
                              !newItemUnit.isEmpty else { return }

                        viewModel.addItem(name: newItemName, quantity: quantity, unit: newItemUnit)
                        newItemName = ""
                        newItemQuantity = ""
                        newItemUnit = "Stück"
                    }
                }
                .padding()
                List {
                    ForEach(viewModel.items) { item in
                        Text("\(item.name ?? "") – \(formattedQuantity(item.quantity)) \(item.unit ?? "")")
                    }
                    .onDelete(perform: viewModel.deleteItem)
                }
            }
            .navigationTitle("Einkaufsliste")
        }
        
        
    }
}

// MARK: - Preview

#Preview {
    ThirdView()
}
