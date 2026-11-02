# Spendly: Expense Manager for iOS

A native SwiftUI app to track expenses with custom categories, budgets, rich filters and charts.
All data stays on the device (SwiftData).

## Requirements

- macOS with **Xcode 16 or later**
- iOS **17.0+** device or simulator

## Build and run

1. Open `Spendly.xcodeproj` in Xcode.
2. Select the **Spendly** target, then **Signing & Capabilities**:
   - Choose your **Team**.
   - Change the **Bundle Identifier** (`com.example.spendly`) to one you own, e.g. `com.yourname.spendly`.
3. Select an iPhone simulator or your device and press **⌘R**.

New source files that you add under `Spendly/` are picked up automatically, because the project uses
Xcode's synchronized folders.

### If the project does not open

The project file uses the Xcode 16 format. On an older Xcode, or if the file has a problem, make it
again with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
rm -rf Spendly.xcodeproj
xcodegen generate
```

## Features

**Overview**
- Month switcher, total spent, and the change against the previous month
- Overall monthly budget progress
- Interactive donut chart by category (tap a slice), with a ranked list you can drill into
- Daily spending bar chart with an average line
- Budget progress for each category, recent expenses, and stat tiles (count, daily average, largest)

**Expenses**
- Add, edit, duplicate and delete expenses (swipe actions and context menu)
- Fields: amount, title, date and time, category, payment method, tags, notes, repeat
- Recurring expenses (daily, weekly, every 2 weeks, monthly, yearly) are created automatically when due
- Search across title, notes, category, tags, payment method and amount
- Filters: date period (presets or custom range), categories (several at once, including
  Uncategorized), amount range, payment methods, tags, and recurring only
- Active filters show as removable chips
- Sort by date, amount, title or category, with section headers and totals for each section
- Export the filtered results to CSV

**Categories**
- Create custom categories with a name, color (palette or custom) and SF Symbol icon
- Optional monthly budget for each category, with progress
- Reorder (Edit button), edit, and delete. When you delete a category, you can keep its expenses
  as Uncategorized or delete them too.
- Tap a category to see its expenses, with all filters available

**Settings**
- Currency (any ISO currency), appearance (System, Light, Dark), and overall monthly budget
- Export all expenses to CSV, add sample data, delete all expenses

## Project structure

```
Spendly/
├── SpendlyApp.swift              App entry point and SwiftData container
├── Models/                       Expense, ExpenseCategory, PaymentMethod, Recurrence
├── Filtering/ExpenseFilter.swift Filter, sort and date-preset logic
├── Services/                     Recurring processor, CSV export, seed and sample data
├── Utilities/                    Settings keys, formatting, theme, preview data
├── Views/
│   ├── RootView.swift            Tab bar
│   ├── Dashboard/                Overview, charts, and month summary
│   ├── Expenses/                 List, row, editor, filter sheet, filter chips
│   ├── Categories/               List and editor
│   ├── Settings/                 Settings and currency picker
│   └── Components/               Shared UI (icons, chips, budget bar, flow layout)
└── Assets.xcassets               App icon and accent color
```

## Notes

- On first launch, the app creates 10 suggested categories. You can edit or delete them.
- To try the app with data, use **Settings → Add Sample Expenses**.
- Changing the currency only changes how amounts are shown. It does not convert them.
