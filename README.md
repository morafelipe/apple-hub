<div align="center">

# 🍎 Apple Hub — Distribution Management Dashboard

**A full-stack enterprise admin panel for managing an Apple authorized distribution center.**  
Built with Next.js 15, React 19, PostgreSQL, and Tailwind CSS 4.

[![Next.js](https://img.shields.io/badge/Next.js-15.5-black?style=for-the-badge&logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![React](https://img.shields.io/badge/React-19.1-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://reactjs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white)](https://tailwindcss.com/)
[![JWT](https://img.shields.io/badge/JWT-Auth-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white)](https://jwt.io/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## 📋 Overview

**Apple Hub** is a production-grade admin dashboard built for internal use at an Apple product distribution center. It provides a centralized platform to manage customers, inventory, orders, returns, warranties, and revenue tracking — all secured behind role-based authentication.

The system implements a full **CRUD** architecture using **Next.js API Routes** as the backend, a **PostgreSQL** relational database with stored procedures and triggers, and **JWT-based authentication** enforced via Next.js middleware.

---

## 📸 Screenshots

> **Login Page**
> 
> ![Login Page](https://placehold.co/900x500?text=Login+Page)

> **Main Dashboard**
> 
> ![Dashboard Home](https://placehold.co/900x500?text=Dashboard+Home)

> **Products Management**
> 
> ![Products](https://placehold.co/900x500?text=Products+Module)

> **Orders & Order Items**
> 
> ![Orders](https://placehold.co/900x500?text=Orders+Module)

> **Customers Module**
> 
> ![Customers](https://placehold.co/900x500?text=Customers+Module)

> **Revenue Tracker**
> 
> ![Revenues](https://placehold.co/900x500?text=Revenue+Module)

---

## ✨ Features

### 🔐 Authentication & Authorization
- Secure login with **bcrypt** password hashing
- **JWT tokens** stored in HTTP-only cookies
- Protected routes enforced at the middleware level (no client-side leaks)
- Two distinct roles with different permissions enforced both at the **application layer** and the **PostgreSQL database layer**:
  - **Admin** — full CRUD access, superuser privileges
  - **Employee** — read, create, and update only; DELETE is blocked at the DB level

### 👥 Customer Management
- Register customers with full profile: name, ID (NUIP), email, age, gender, address, phone
- Edit and update customer records
- Search and list all registered customers

### 📦 Product Catalog
- Add Apple products with reference code, category, price, stock, and description
- Edit product details and pricing
- **Automatic stock management**: stock decreases on new orders and is restored when orders are cancelled or returned — handled by a **PostgreSQL trigger**

### 🛒 Order Processing
- Create multi-item orders linked to customers and a delivery address
- Orders are created via a **PostgreSQL stored procedure** (`create_order`) that atomically inserts the order, all order items, and calculates the total
- Track order and item-level statuses: `En Proceso`, `Entregado`, `Cancelado`, `Devuelto`

### 🔄 Returns & Warranties
- Returns are automatically registered via a **PostgreSQL trigger** when an order item is marked as `Devuelto` or `Cancelado`
- Warranties are automatically created via trigger when an item is flagged as `Garantía`
- Manage and update the status of active returns and warranties

### 💰 Revenue Tracking
- Real-time total revenue calculation via a **PostgreSQL function** (`total_revenues`)
- Counts only fulfilled order items (excludes cancelled/returned)

### 🔑 License Management
- Dedicated module for managing Apple product licenses

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Next.js 15.5 (App Router) |
| UI Library | React 19.1 |
| Styling | Tailwind CSS 4 + CSS Modules |
| Database | PostgreSQL (pg 8.16) |
| ORM / Query | Raw SQL with `node-postgres` |
| Authentication | JWT (jsonwebtoken 9.0) + bcrypt 6.0 |
| Environment | dotenv |
| Linting | ESLint 9 |

### Database Architecture
- **7 relational tables**: `users`, `customers`, `products`, `orders`, `order_items`, `warranties`, `returns`
- **1 stored procedure**: `create_order()` — atomic multi-item order creation
- **1 function**: `total_revenues()` — revenue aggregation
- **3 triggers**: stock update, warranty auto-insert, return auto-insert
- **2 database roles**: `admin_role` (SUPERUSER) and `employee_role` (no DELETE)
- **3 connection pools**: default, admin, and employee — dynamically assigned per authenticated role

---

## 🚀 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [PostgreSQL](https://www.postgresql.org/) v14+
- npm or yarn

### Installation

**1. Clone the repository**
```bash
git clone https://github.com/your-username/apple-hub.git
cd apple-hub
```

**2. Install dependencies**
```bash
npm install
```

**3. Set up the database**

Open your PostgreSQL client (psql, pgAdmin, or TablePlus) and run the full schema file:

```bash
psql -U postgres -d your_database_name -f src/lib/db/apple_hub_tovscode.sql
```

This will create all tables, stored procedures, triggers, functions, database roles, and seed the database with sample data.

**4. Configure environment variables**

Create a `.env.local` file in the project root:

```env
# Default connection (used for seeding / migrations)
DB_DEFAULT_USER=postgres
DB_HOST=localhost
DB_NAME=apple_hub
DB_PASSWORD_DEFAULT=your_postgres_password
DB_PORT=5432

# Admin role connection pool
DB_ADMIN_USER=admin_user
DB_PASSWORD_ADMIN=admin2025

# Employee role connection pool
DB_EMPLOYEE_USER=employee_user
DB_PASSWORD_EMPLOYEE=employee2025

# JWT
JWT_SECRET=your_super_secret_key_here
```

**5. Run the development server**
```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Sample Credentials

After running the SQL seed file, you can log in with:

| Role | Email | Password |
|---|---|---|
| Admin | `jmncamilo@gmail.com` | `admin` |
| Employee | `correo-prueba01@gmail.com` | `empleado01` |

> **Note:** These are seeded with plain-text passwords for development purposes. In production, passwords should be hashed with bcrypt before insertion.

---

## 📁 Project Structure

```
src/
├── app/
│   ├── api/                    # REST API routes (Next.js Route Handlers)
│   │   ├── customers/
│   │   ├── products/
│   │   ├── orders/
│   │   ├── order-items/
│   │   ├── warranties/
│   │   ├── returns/
│   │   ├── revenues/
│   │   ├── licence/
│   │   ├── login/
│   │   └── logout/
│   ├── dashboard/              # Protected dashboard pages
│   │   ├── customers/
│   │   ├── products/
│   │   ├── orders/
│   │   ├── revenues/
│   │   ├── license/
│   │   └── settings/
│   └── page.js                 # Login page (public)
├── components/
│   ├── cards/                  # ProductCard, OrderCard, CustomerCard, WarrantyCard
│   ├── common/                 # Loader, ErrorMessage, LogoutConfirmation
│   ├── forms/                  # CustomerForm, ProductForm, ReturnForm
│   └── views/                  # NewOrderView, ReturnsView, WarrantiesView, ProductsView
├── hooks/
│   ├── useFetch.js             # Data fetching hook
│   ├── useFetchAction.js       # Mutation hook (POST/PUT/DELETE)
│   └── useForm.js              # Controlled form state
├── lib/
│   ├── db/
│   │   ├── index.js            # Connection pools (default, admin, employee)
│   │   ├── setPoolByRole.js    # Dynamic pool selector by user role
│   │   └── apple_hub_tovscode.sql  # Full DB schema + seed data
│   ├── random/                 # Mock data generators (dev only)
│   └── utils/                  # Validators, type casters, fetch helpers
└── middleware.js               # JWT route protection for /dashboard/**
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 👤 Author

**Andres Felipe Mora Mancipe**  
Full-Stack & Mobile Developer

[![GitHub](https://img.shields.io/badge/GitHub-@andresfelipemora-181717?style=flat-square&logo=github)](https://github.com/andresfelipemora)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Andres_Mora-0077B5?style=flat-square&logo=linkedin)](https://linkedin.com/in/andresfelipemora)
[![Email](https://img.shields.io/badge/Email-andresfelipemoramancipe@gmail.com-D14836?style=flat-square&logo=gmail&logoColor=white)](mailto:andresfelipemoramancipe@gmail.com)

**Team members**
- Camilo Jiménez
- Juan Esteban Aponte

---

<div align="center">
  <sub>Built with ❤️ and Next.js</sub>
</div>
