# Property Portal — Project Spec

## 1. Overview
A property portal for Myanmar covering three locations — Yangon, Mandalay, and Bago.
Users can create a free account and post property listings for **Sale** or **Rent**.
Search and filtering are public (no login required). Web ships first; mobile ships later.

## 2. Repositories
Three separate repos, each independently deployable:

| Repo | Purpose | Stack |
|---|---|---|
| `property-portal-api` | Backend REST API | Express, TypeScript, Prisma 7, SQLite |
| `property-portal-app` | Web frontend | React, TypeScript, Vite, shadcn/ui |
| `property-portal-mobile` | Mobile app (built later) | React Native, Expo, TypeScript |

All three consume the same API. The mobile repo is scaffolded but not implemented in this phase.

## 3. Tech Stack

### API (`property-portal-api`)
- Express + TypeScript
- Prisma 7 ORM + SQLite provider (schema in `prisma/schema.prisma`, migrations via `prisma migrate`)
- Auth: `bcrypt` (password hashing) + `jsonwebtoken` (JWT sessions)
- Validation: `zod`
- File uploads: `multer`, saved to local `/uploads` directory, served statically at `/uploads/*`
- Seed script (`prisma/seed.ts`, run via `prisma db seed`) for sample users, listings, and photo URLs

### Web (`property-portal-app`)
- React + TypeScript + Vite
- shadcn/ui, initialized with preset `--preset b7ClNFsdU`
- Tailwind CSS (via shadcn)
- TanStack Query for API data fetching/caching
- React Router for routing
- React Hook Form + zod for form validation

### Mobile (`property-portal-mobile`) — scaffolded later
- Expo + React Native + TypeScript
- React Navigation
- NativeWind for styling (to match web's Tailwind conventions)
- Shares API contract with web; no code written in this phase

## 4. Data Model (Prisma schema, SQLite provider)

```prisma
// prisma/schema.prisma
datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

enum ListingType {
  SALE
  RENT
}

enum PropertyType {
  CONDO
  APARTMENT
  HOUSE
  LAND
}

enum City {
  YANGON
  MANDALAY
  BAGO
}

enum ListingStatus {
  ACTIVE
  INACTIVE
}

enum UserRole {
  USER
  ADMIN
}

model User {
  id           Int       @id @default(autoincrement())
  name         String
  email        String    @unique
  passwordHash String
  phone        String?
  role         UserRole  @default(USER)
  createdAt    DateTime  @default(now())
  listings     Listing[]
}

model Listing {
  id           Int            @id @default(autoincrement())
  userId       Int
  user         User           @relation(fields: [userId], references: [id])
  title        String
  description  String
  listingType  ListingType
  propertyType PropertyType
  city         City
  township     String?
  address      String?
  priceMmk     Int
  bedrooms     Int?
  bathrooms    Int?
  areaSqft     Int?
  status       ListingStatus  @default(ACTIVE)
  createdAt    DateTime       @default(now())
  updatedAt    DateTime       @updatedAt
  photos       ListingPhoto[]
}

model ListingPhoto {
  id        Int      @id @default(autoincrement())
  listingId Int
  listing   Listing  @relation(fields: [listingId], references: [id])
  url       String
  sortOrder Int      @default(0)
}
```

## 5. Auth & Roles
- `POST /auth/register` — create account (name, email, password, phone). New accounts default to role `USER`.
- `POST /auth/login` — returns JWT (JWT payload includes `userId` and `role`)
- `GET /auth/me` — current user from JWT, includes `role`
- JWT required (as `Authorization: Bearer <token>`) to create, edit, or delete a listing
- Two roles:
  - **USER** (default) — can create listings and edit/delete only their own listings
  - **ADMIN** — can view, edit, deactivate, or delete *any* listing (moderation), and list all users
- Role is not self-assignable via the API; admin accounts are created via the seed script only (no public "become admin" endpoint)

## 6. API Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | none | create account |
| POST | `/auth/login` | none | login, returns JWT |
| GET | `/auth/me` | required | current user |
| GET | `/listings` | none | public search/filter (see §7) |
| GET | `/listings/:id` | none | listing detail incl. photos |
| POST | `/listings` | required | create listing (auto-published) |
| PUT | `/listings/:id` | required, owner only | update listing |
| DELETE | `/listings/:id` | required, owner only | delete listing |
| POST | `/listings/:id/photos` | required, owner only | upload photo(s), multipart |
| DELETE | `/listings/:id/photos/:photoId` | required, owner only | remove a photo |
| GET | `/users/me/listings` | required | current user's own listings |
| GET | `/admin/listings` | required, ADMIN only | all listings regardless of owner, incl. filters |
| PUT | `/admin/listings/:id` | required, ADMIN only | edit or change status of any listing |
| DELETE | `/admin/listings/:id` | required, ADMIN only | delete any listing |
| GET | `/admin/users` | required, ADMIN only | list all users |

## 7. Public Search & Filter
`GET /listings` supports query params:
- `city` — Yangon / Mandalay / Bago
- `listing_type` — sale / rent
- `property_type` — condo / apartment / house / land
- `min_price`, `max_price` (MMK)
- `bedrooms` (minimum)
- `q` — keyword search across title/description
- `sort` — `newest` (default) / `price_asc` / `price_desc`
- `page`, `limit` — pagination

No authentication required for search, filter, or viewing listing details.

## 8. Web App Pages
- **Home** — search bar + filter panel + listing results grid
- **Listing detail** — photo gallery, full details, contact info of poster
- **Login / Register**
- **Post a listing** — form (auth required)
- **My listings** — manage (edit/delete) own listings, upload/remove photos
- **Admin dashboard** (`/admin`, ADMIN role only) — table of all listings across all owners with filters, ability to edit/deactivate/delete any listing; simple user list

## 9. Sample / Seed Data
- Seed script (`prisma/seed.ts`, run via `prisma db seed`) populates the database via Prisma Client with:
  - ~5 sample users (role `USER`)
  - 1 dedicated demo admin user (role `ADMIN`)
  - ~15–20 sample listings, distributed across Yangon, Mandalay, and Bago, mixing `sale`/`rent` and all four property types
  - 3–5 Unsplash photo URLs per listing (real estate / interior photography), no binary images committed to the repo

### Demo accounts (for manual testing of each role)
| Role | Email | Password |
|---|---|---|
| USER (listing owner) | `demo.owner@example.com` | `DemoPass123!` |
| ADMIN | `demo.admin@example.com` | `DemoPass123!` |

These are seeded with fixed, known credentials (unlike the other randomized sample users) specifically so they can be used to log in and test owner-only and admin-only flows.

## 10. shadcn/ui Setup
When scaffolding `property-portal-app`, initialize shadcn with:
```
npx shadcn@latest init --preset b7ClNFsdU
```
Add components as needed per page (e.g. `card`, `input`, `select`, `slider`, `dialog`, `form`, `badge`).

## 11. Out of Scope (this phase)
- Mobile app implementation (repo will be scaffolded but left empty/minimal)
- Payments or paid listing tiers
- In-app messaging between buyer and seller
- Saved/favorite listings
- Cloud image storage (local disk only for now)
- Map/geolocation search
