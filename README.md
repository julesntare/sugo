# Sugo

A Flutter-based mobile application for forecasting budget usage between a certain period of months to reach a specific financial goal.

## Features

- **Budget Creation**: Create budgets with a target amount and time period (start/end dates)
- **Budget Items**: Add items with flexible frequency options:
  - One-time purchases
  - Weekly recurring expenses
  - Monthly recurring expenses
- **Sub-Items**: Support for nested sub-items within budget items for detailed expense tracking
- **Smart Deductions**: Automatic calculation of deductions based on frequency and time periods
- **Monthly Tracking**: Track budget usage month-by-month with visual progress indicators
- **Checklist System**: Mark items as completed per month
- **Date Overrides**: Override default salary dates and item dates per month
- **Amount Overrides**: Adjust specific item amounts for individual months
- **Visual Charts**: Simple bar charts to visualize budget allocation and remaining amounts
- **Data Persistence**: Local database storage using SQLite

## Screenshots

[Add screenshots here]

## Tech Stack

- **Framework**: Flutter 3.10+
- **Language**: Dart
- **Database**: SQLite (via sqflite package)
- **State Management**: StatefulWidget (built-in Flutter state management)
- **Local Storage**: SharedPreferences for simple data, SQLite for complex relational data
- **Date Formatting**: intl package

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── models/
│   ├── budget.dart                     # Budget model with forecasting logic
│   ├── budget_item.dart                # Budget item model
│   ├── sub_item.dart                   # Sub-item model
│   └── forecast.dart                   # Forecast calculation model
├── screens/
│   ├── home_screen.dart                # Main dashboard
│   ├── budgets_screen.dart             # List of all budgets
│   ├── budget_detail_screen.dart       # Budget overview with monthly breakdown
│   ├── item_detail_screen.dart         # Detailed view of budget items
│   ├── create_budget_screen.dart       # Budget creation form
│   └── edit_item_dialog.dart           # Edit budget item dialog
├── widgets/
│   ├── app_theme.dart                  # App-wide theme and styling
│   ├── budget_card.dart                # Budget card component
│   ├── create_budget_dialog.dart       # Budget creation dialog
│   ├── simple_bar_chart.dart           # Custom bar chart widget
│   ├── sub_item_dialog.dart            # Sub-item creation/edit dialog
│   └── sub_items_list.dart             # Sub-items list component
└── services/
    ├── database_helper.dart            # SQLite database operations
    └── storage.dart                    # SharedPreferences wrapper
```

## Installation

### Prerequisites

- Flutter SDK (3.10 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- An IDE (VS Code, Android Studio, or IntelliJ IDEA)

### Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/julesntare/sugo.git
   cd sugo
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. (Optional) Generate launcher icons:

   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Creating a Budget

1. Tap the "+" button on the home screen
2. Enter budget title, amount, start date, and end date
3. Tap "Create" to save

### Adding Budget Items

1. Open a budget from the budgets list
2. Tap "Add Item"
3. Choose frequency (once, weekly, or monthly)
4. Enter item name, amount, and start date
5. (Optional) Enable sub-items for nested tracking

### Managing Sub-Items

1. Open an item that has sub-items enabled
2. Tap "Add Sub-Item"
3. Configure sub-item frequency, amount, and dates
4. Sub-items are automatically deducted from the parent budget

### Monthly Tracking

- View monthly breakdown in the budget detail screen
- Check/uncheck items as completed
- Override specific dates or amounts per month as needed
- Monitor remaining budget with visual indicators

## Database Schema

### Tables

- **budgets**: Stores budget information
- **budget_items**: Stores budget items linked to budgets
- **sub_items**: Stores sub-items linked to budget items
- **checklist**: Tracks completion status per month/item
- **month_salary_overrides**: Custom salary dates per month
- **month_item_date_overrides**: Custom item dates per month
- **month_item_amount_overrides**: Custom amounts per month

## Building for Production

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## Development

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

### Formatting Code

```bash
dart format lib/
```

## Dependencies

- **flutter**: SDK
- **cupertino_icons**: iOS-style icons
- **intl**: Internationalization and date formatting
- **shared_preferences**: Simple key-value storage
- **sqflite**: SQLite database
- **path**: Path manipulation utilities

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Contact

For questions or support, please open an issue on the GitHub repository.
