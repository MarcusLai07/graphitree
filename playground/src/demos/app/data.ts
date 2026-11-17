/** Shared, realistic sample data for the app-component pages (consumer-goods ops in Malaysia). */

export type Customer = { id: string; name: string; area: string; channel: string; terms: string }

export const customers: Customer[] = [
  { id: "C-1042", name: "Mydin Subang Jaya", area: "Selangor", channel: "Modern trade", terms: "30 days" },
  { id: "C-1077", name: "Jaya Grocer Bangsar", area: "Kuala Lumpur", channel: "Modern trade", terms: "45 days" },
  { id: "C-2210", name: "99 Speedmart Puchong", area: "Selangor", channel: "Modern trade", terms: "30 days" },
  { id: "C-3118", name: "Kedai Runcit Ahmad", area: "Kelantan", channel: "General trade", terms: "COD" },
  { id: "C-3150", name: "Pasar Mini Seri Kembangan", area: "Selangor", channel: "General trade", terms: "14 days" },
  { id: "C-4401", name: "Borneo Mart Kuching", area: "Sarawak", channel: "Distributor", terms: "60 days" },
  { id: "C-4415", name: "KK Wholesale Centre", area: "Sabah", channel: "Distributor", terms: "60 days" },
  { id: "C-5002", name: "Penang Fresh Market", area: "Penang", channel: "General trade", terms: "14 days" },
  { id: "C-5090", name: "Ipoh Family Store", area: "Perak", channel: "General trade", terms: "COD" },
  { id: "C-6120", name: "Melaka Trading Co.", area: "Melaka", channel: "Distributor", terms: "45 days" },
]

export type Warehouse = { id: string; name: string; region: string; capacity: number }

export const warehouses: Warehouse[] = [
  { id: "SA", name: "Shah Alam DC", region: "Central", capacity: 72 },
  { id: "PG", name: "Penang Hub", region: "North", capacity: 58 },
  { id: "JB", name: "Johor Bahru DC", region: "South", capacity: 91 },
  { id: "KC", name: "Kuching Depot", region: "Sarawak", capacity: 34 },
  { id: "KK", name: "Kota Kinabalu Depot", region: "Sabah", capacity: 47 },
]

export type Sku = { sku: string; name: string; category: string; price: number; onHand: number }

export const skus: Sku[] = [
  { sku: "BEV-TT30", name: "Teh Tarik 3-in-1 (30 sticks)", category: "Beverages", price: 18.9, onHand: 1240 },
  { sku: "BEV-KOK5", name: "Kopi O Kaw 500g", category: "Beverages", price: 14.5, onHand: 86 },
  { sku: "BEV-MLO1", name: "Malted Chocolate Drink 1kg", category: "Beverages", price: 27.0, onHand: 412 },
  { sku: "NDL-KR5", name: "Instant Noodle Kari 5-pack", category: "Noodles", price: 6.8, onHand: 3100 },
  { sku: "NDL-AYM5", name: "Instant Noodle Ayam 5-pack", category: "Noodles", price: 6.8, onHand: 0 },
  { sku: "SAU-SB200", name: "Sambal Belacan 200g", category: "Sauces & pastes", price: 7.9, onHand: 540 },
  { sku: "SAU-CS340", name: "Chilli Sauce 340ml", category: "Sauces & pastes", price: 4.2, onHand: 2210 },
  { sku: "SPR-KP400", name: "Kaya Pandan 400g", category: "Spreads", price: 9.5, onHand: 75 },
  { sku: "CKG-CM1L", name: "Coconut Milk 1L", category: "Cooking", price: 8.3, onHand: 960 },
  { sku: "CKG-PO5", name: "Palm Cooking Oil 5kg", category: "Cooking", price: 32.5, onHand: 188 },
]

export const salesChannels = [
  "Modern trade",
  "General trade",
  "Distributor",
  "Shopee",
  "Lazada",
  "TikTok Shop",
  "B2B portal",
  "Export",
]

export const orderStatuses = ["Draft", "Confirmed", "Picking", "Packed", "Shipped", "Delivered", "Cancelled"] as const
export type OrderStatus = (typeof orderStatuses)[number]

export type OrderLine = { sku: string; name: string; qty: number; price: number }

export type Order = {
  id: string
  customer: string
  status: OrderStatus
  warehouse: string
  eta: string
  lines: OrderLine[]
}

export const order4821: Order = {
  id: "#4821",
  customer: "Mydin Subang Jaya",
  status: "Picking",
  warehouse: "Shah Alam DC",
  eta: "Tue, 18 Nov",
  lines: [
    { sku: "BEV-TT30", name: "Teh Tarik 3-in-1 (30 sticks)", qty: 60, price: 18.9 },
    { sku: "NDL-KR5", name: "Instant Noodle Kari 5-pack", qty: 120, price: 6.8 },
    { sku: "SAU-SB200", name: "Sambal Belacan 200g", qty: 48, price: 7.9 },
    { sku: "CKG-CM1L", name: "Coconut Milk 1L", qty: 36, price: 8.3 },
  ],
}

export const recentOrders = [
  { id: "#4821", customer: "Mydin Subang Jaya", total: 2665.2, status: "Picking" },
  { id: "#4820", customer: "Kedai Runcit Ahmad", total: 412.0, status: "Confirmed" },
  { id: "#4819", customer: "Borneo Mart Kuching", total: 9810.5, status: "Shipped" },
  { id: "#4818", customer: "Jaya Grocer Bangsar", total: 1288.4, status: "Delivered" },
  { id: "#4817", customer: "99 Speedmart Puchong", total: 3540.0, status: "Packed" },
  { id: "#4816", customer: "Penang Fresh Market", total: 640.8, status: "Cancelled" },
  { id: "#4815", customer: "KK Wholesale Centre", total: 12450.0, status: "Delivered" },
  { id: "#4814", customer: "Ipoh Family Store", total: 220.5, status: "Shipped" },
]

export const rm = (n: number) =>
  new Intl.NumberFormat("en-MY", { style: "currency", currency: "MYR" }).format(n)

/** Pretend network latency for "async" demos. */
export const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
