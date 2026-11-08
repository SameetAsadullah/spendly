# Spendly: Expense Manager for iOS

A native SwiftUI app to track expenses with custom categories and subcategories, budgets, filters
and charts. All data stays on the device (SwiftData).

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

To run the tests, press **⌘U** in Xcode, or run:

```bash
xcodebuild test -project Spendly.xcodeproj -scheme Spendly -destination "platform=iOS Simulator,name=iPhone 17"
```

Change build settings in `project.yml`, not in Xcode. `xcodegen generate` replaces the project and
removes changes that you made in Xcode. New source files under `Spendly/` do not need a new project,
because the project uses a synchronized folder.

## Keep the app installed with a free Apple ID

With a free Apple ID, Xcode signs the app with a provisioning profile that expires after 7 days.
Then the app does not open until you install it again. Two scripts in `scripts/` do this for you.
They build `origin/main` of this repository with the bundle identifier and team in `project.yml`.

- `install-on-iphone.sh <device-id>` builds the app from a clean checkout in
  `~/Library/Application Support/Spendly` and installs it over the app on the iPhone. Your data
  stays. Get the device ID from `xcrun devicectl list devices`.
- `setup-auto-reinstall.sh <device-id> [hour]` adds a launchd agent that runs the install script
  every day at that hour (default 23). It installs again only when the installed build has 2 days
  or less left. It logs to `~/Library/Application Support/Spendly/reinstall.log` and shows a macOS
  notification for each install or failure.

The iPhone must be on the same network as the Mac, with **Connect via network** turned on for it in
Xcode → Window → Devices and Simulators.

## Features

**Overview**
- Month switcher, total spent, and the change against the previous month
- An eye button that hides the amounts on the summary card
- Overall monthly budget progress
- Interactive donut chart by category (tap a slice), with a ranked list you can drill into. A
  selected category shows its subcategories.
- Daily spending bar chart with an average line
- Budget progress for each category in the ranked list, recent expenses, and stat tiles (count,
  daily average, largest)
- Totals for the last 6 months. Tap See all for Trends: monthly totals for the last 6 or 12 months, for all categories or one category, with the
  change against the month before. One category can also be broken down by subcategory. Tap a
  month to see its expenses.

**Expenses**
- Add, edit, duplicate and delete expenses (swipe actions and context menu)
- Fields: amount, title, date and time, category and subcategory, payment method, tags, notes,
  repeat
- Recurring expenses (daily, weekly, every 2 weeks, monthly, yearly) are created automatically when due
- Search across title, notes, category, tags, payment method and amount
- Filters: date period (presets or custom range), categories and subcategories (several at once,
  including Uncategorized), amount range, payment methods, tags, and recurring only
- Active filters show as removable chips
- Sort by date, amount, title or category, with section headers and totals for each section
- Expenses in a subcategory show its path, such as Food & Dining › Coffee. A list for one category
  shows its budget.
- Export the filtered results to CSV

**Categories**
- Create custom categories with a name, color (palette or custom) and SF Symbol icon
- Subcategories, one level deep, such as Coffee or Fuel. A subcategory uses the color of its
  parent and can have its own budget, which also counts toward the parent's budget.
- Optional monthly budget for each category, with progress
- Categories are sorted by what you spent on them this month
- Tap a category to open its detail screen: spending for each month, the change against the month
  before, the budget, a breakdown by subcategory, and its expenses
- Swipe left to delete a category. When you delete a category, you can keep its expenses as
  Uncategorized or delete them too. When you delete a subcategory, its expenses move to the parent.
- Touch and hold a category to open, edit or delete it, add a subcategory, or show its expenses
  with all filters available

**Settings**
- Currency (any ISO currency), appearance (System, Light, Dark), and overall monthly budget
- App lock with Face ID, Touch ID or the device passcode, at launch and when you come back to the
  app. While the app is locked, it is blurred under a frosted cover. The cover also hides open
  sheets and the app's picture in the app switcher.
- Export all expenses to CSV, delete all expenses

## Project structure

```
Spendly/
├── SpendlyApp.swift              App entry point and SwiftData container
├── Models/                       Expense, ExpenseCategory, PaymentMethod, Recurrence, versioned schema
├── Filtering/ExpenseFilter.swift Filter, sort and date-preset logic
├── Services/                     Recurring processor, CSV export, default categories, device authentication
├── Utilities/                    Settings keys, formatting, theme, preview data
├── Views/
│   ├── RootView.swift            Tab bar
│   ├── Dashboard/                Overview, charts, month summary, and trends
│   ├── Expenses/                 List, row, editor, filter sheet, filter chips
│   ├── Categories/               List, detail screen, category and subcategory editors
│   ├── Settings/                 Settings and currency picker
│   ├── Lock/                     App lock: gate, frosted overlay and its window
│   └── Components/               Shared UI (icons, chips, budget bar, stat tiles, flow layout)
└── Assets.xcassets               App icon and accent color
SpendlyTests/                     Swift Testing tests for subcategories, filters and migrations
scripts/                          Install and auto-reinstall scripts for an iPhone
```

## Notes

- On first launch, the app creates 10 suggested categories. You can edit or delete them.
- Changing the currency only changes how amounts are shown. It does not convert them.
