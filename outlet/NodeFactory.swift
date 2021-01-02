final class NodeFactory {
    func nodes() -> [Node] {
        return [
            .init(name: "💰 Offers", children: [
                .init(name: "🍦 Ice Cream", children: [
                    .init(name: "💵 $0.24 back")
                ]),
                .init(name: "☕️ Coffee", children: [
                    .init(name: "💵 $0.75 back")
                ]),
                .init(name: "🍔 Burger", children: [
                    .init(name: "💵 $1.00 back")
                ])
            ]),
            .init(name: "Retailers", children: [
                .init(name: "King Soopers"),
                .init(name: "Walmart"),
                .init(name: "Target"),
            ])
        ]
    }
}
