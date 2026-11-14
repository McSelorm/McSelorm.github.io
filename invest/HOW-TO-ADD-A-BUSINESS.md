# How to add an approved business

Applications arrive in your email. When you approve one, add it to `businesses.json` (or just ask Claude to do it).

Each business looks like this. Put a comma between businesses.

```json
[
  {
    "name": "Ama's Fresh Juice",
    "owner": "Ama Mensah",
    "type": "Food & drinks",
    "location": "Kumasi",
    "stage": "1 to 3 years",
    "monthlySales": 3000,
    "about": "Fresh fruit juice sold to offices and schools.",
    "amount": 5000,
    "useOfMoney": "A bigger freezer and a delivery bike",
    "investorGets": "20% of profits for 2 years",
    "phone": "024 123 4567"
  }
]
```

- Leave out `"phone"` if the owner did not tick "show my WhatsApp number".
- `type` must be one of: Food & drinks, Farming, Shop / trading, Fashion & beauty, Transport & delivery, Tech & phones, Education, Health, Building & repairs, Services, Other.
- To remove a business, delete its `{ ... }` block.
