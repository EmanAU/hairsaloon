# Business COMB

## Online business and customer flavors

Flutter and the Next.js admin portal are separate projects in this repository.
Run `flutter run --flavor business` or `flutter run --flavor customer` from the
root. The business flavor includes an entry to the existing offline app.
See [Flutter setup](docs/flutter-online.md), [admin setup](web/README.md), and
[backend setup](supabase/README.md). Online credentials can be added later.

## Existing offline workspace

Android-only Flutter salon management app with local storage. Registration and phone/password login use accounts saved on this device; no SMS verification or cloud services are required.

Bills, customers, employees, services, categories, expenses and settings persist in Hive. Business profile and local accounts/session persist in SharedPreferences. Logout preserves business data and profile. Accounts share the single salon workspace on this device.

Previously cloud-only accounts must register locally. Existing Hive and local business profile data remain available. Cloud-only records are not downloaded automatically.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```
<<<<<<< HEAD
=======
Open App
    └── Splash Screen (Logo + "Business COMB")
            └── Tap "Continue with Gmail"
                    └── Google Auth
                            ├── New User → Business Registration Form
                            │       (Name, Phone, Type, City, Area, Address)
                            │               └── Tap "Register" → Dashboard
                            └── Existing User → Dashboard (directly)
```

---

### 2. DASHBOARD (Home)
```
Dashboard
    ├── Today Appointments (05) → [Appointments Screen]
    ├── Finance Card → Reports & Finance
    ├── Employees Card → Employees Screen
    ├── Rate List Card → Rate List Screen
    └── Customers Card → Customers Screen
```

---

### 3. SIDE MENU (Hamburger ☰)
```
Side Menu
    ├── Profile Settings
    ├── Category (manage service categories)
    ├── Service List → Rate List Screen
    ├── Expense List → Expense Types Screen
    ├── Currency Change
    ├── Tax Rate (set %, e.g. 17%)
    └── Logout
```

---

### 4. RATE LIST / SERVICES
```
Rate List (09)
    ├── Tabs: Men's Grooming | Skincare | Male | Female | Child | Women
    ├── Each row: Service Name | Gender | Age Group | Price | ⋮ (Edit/Delete)
    └── Tap + (Add New)
            └── New Service Form
                    (Category → Service → Gender → Age Group → Price)
                            └── "Save Service" → Back to Rate List
```

---

### 5. BILLING / POS
```
Billing (Bottom Nav)
    ├── Sub Total | Tax 17% | Grand Total (live updating)
    ├── Enter Customer Phone + "Add New"
    ├── Select Employee
    ├── Payment Type (Cash / Online)
    ├── Available Services Grid (tap to add)
    │       └── Each tap → updates Sub Total instantly
    └── Tap "Save Bill" → Bill Saved → Finance Report updated
```

---

### 6. EMPLOYEES
```
Employees (06)
    ├── Tabs: Active | Deactive | Male | Female
    ├── Tap + → New Employee Form
    │       (First Name, Last Name, Phone, CNIC, Address)
    │               └── "Save Employee" → Added to list
    └── Tap ⋮ on any employee
            ├── Agreement → Employee Agreement Form
            │       (Employee, Type, Basic Salary, Commission %, Description)
            │               └── "Save Agreement" → Commission rules set
            ├── Update → Edit employee details
            ├── Delete → Remove employee
            └── Deactive → Move to Deactive tab
```

---

### 7. EXPENSES
```
Expense (Bottom Nav)
    ├── Total Monthly Expenses | Today Expenses
    ├── Tabs: Paid | Unpaid
    ├── Recent Transactions list
    ├── Tap "Add New Expense"
    │       └── Form: Date | Employee | Type | Amount | Qty | Status | Payment | Notes
    │               └── "Save Expense" → Added to list
    └── Gear ⚙ → Expense Types Screen
            └── Add/Remove categories (Coffee, Electricity, Internet…)
```

---

### 8. REPORTS & FINANCE
```
Finance (from Dashboard or after Billing)
    ├── Date | Today Sale (Rs.)
    ├── Profit (↑ green) vs Expenses (↓ red)
    └── Employee Income List
            └── Tap any Employee → Individual Earnings Screen
                    ├── Total Earning | Due Amount
                    ├── Daily breakdown table (Earning | Paid | Due)
                    └── "Settle Up" → Marks salary as paid
```

---

### 9. APPOINTMENTS
```
Appointments (Bottom Nav)
    └── Today's appointments (05 shown on Dashboard)
        [Full calendar/booking — screen not fully shown in PDF]
```

---

### BOTTOM NAVIGATION (Always Visible)
```
[ Home ] [ Billing ] [ Expense ] [ Appointment ]
```

---

### COMPLETE USER JOURNEY (One Day in the Salon)
```
Login → Dashboard
    → Add services (Rate List) if new setup
    → Customer arrives → Billing → Select services → Save Bill
    → Record any expenses (tea, electricity) → Expense
    → End of day → Finance → Check profit vs expenses
    → Settle employee commissions → Settle Up
    → Logout
```

---

That's the full flow of all 9 modules across all 15 screens. 
>>>>>>> 2a8880c51df0302dd250bc5187648779f1b64524
