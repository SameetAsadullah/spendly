# Spendly: Expense Manager for iOS

A native SwiftUI app to track expenses with custom categories, budgets, rich filters and charts.
All data stays on the device (SwiftData).

## Requirements

- macOS with **Xcode 16 or later**
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46 or later: `brew install xcodegen`
- iOS **17.0+** device or simulator

## Build and run

The Xcode project is not in the repository. XcodeGen makes it from `project.yml`.

1. Make the project:

   ```bash
   xcodegen generate
   ```

2. Open `Spendly.xcodeproj` in Xcode.
3. Select an iPhone simulator and press **⌘R**.

To run on your own device, add your team and a bundle identifier that you own to the `Spendly` target
in `project.yml`, then run `xcodegen generate` again:

```yaml
        DEVELOPMENT_TEAM: ABCDE12345
        PRODUCT_BUNDLE_IDENTIFIER: com.yourname.spendly
```

Change build settings in `project.yml`, not in Xcode. `xcodegen generate` replaces the project and
removes changes that you made in Xcode. New source files under `Spendly/` do not need a new project,
because the project uses a synchronized folder.

## Features

**Overview**
- Month switcher, total spent, and the change against the previous month
- Overall monthly budget progress
- Interactive donut chart by category (tap a slice), with a ranked list you can drill into
- Daily spending bar chart with an average line
- Budget progress for each category in the ranked list, recent expenses, and stat tiles (count,
  daily average, largest)
- Totals for the last 6 months. Tap See all for Trends: monthly totals for the last 6 or 12 months, for all categories or one category, with the
  change against the month before. Tap a month to see its expenses.

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
- Categories are sorted by what you spent on them this month
- Tap a category to edit it. Swipe left to delete it. When you delete a category, you can keep its
  expenses as Uncategorized or delete them too.
- Touch and hold a category, then tap Show Expenses to see its expenses, with all filters available

**Settings**
- Currency (any ISO currency), appearance (System, Light, Dark), and overall monthly budget
- App lock with Face ID, Touch ID or the device passcode, at launch and when you come back to the app
- Export all expenses to CSV, delete all expenses

## Project structure

```
Spendly/
├── SpendlyApp.swift              App entry point and SwiftData container
├── Models/                       Expense, ExpenseCategory, PaymentMethod, Recurrence, versioned schema
├── Filtering/ExpenseFilter.swift Filter, sort and date-preset logic
├── Services/                     Recurring processor, CSV export, seed and sample data, device authentication
├── Utilities/                    Settings keys, formatting, theme, preview data
├── Views/
│   ├── RootView.swift            Tab bar
│   ├── Dashboard/                Overview, charts, month summary, and trends
│   ├── Expenses/                 List, row, editor, filter sheet, filter chips
│   ├── Categories/               List and editor
│   ├── Settings/                 Settings and currency picker
│   ├── Lock/                     App lock screen
│   └── Components/               Shared UI (icons, chips, budget bar, flow layout)
└── Assets.xcassets               App icon and accent color
```

## Notes

- On first launch, the app creates 10 suggested categories. You can edit or delete them.
- Changing the currency only changes how amounts are shown. It does not convert them.
