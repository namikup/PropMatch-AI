export interface ProjectData {
  id: string;
  ownerId: string;
  name: string;
  developer: string;
  location: string;
  state: string;
  propertyType: string;
  startingPrice: number;
  maximumPrice: number;
  bedrooms: number;
  bathrooms: number;
  builtUpArea: number;
  facilities: string[];
  nearbyAmenities: string[];
  description: string;
  purpose: string;
  status: string;
  imageUrls?: string[];
  brochures?: string[];
  createdAt?: string;
  updatedAt?: string;
}

export interface BuyerData {
  id: string;
  ownerId: string;
  fullName: string;
  email?: string;
  phone?: string;
  preferredLocation: string;
  preferredState: string;
  propertyType: string;
  budgetMin: number;
  budgetMax: number;
  bedroomsNeeded: number;
  purchasePurpose: string;
  buyingTimeline: string;
  hasMarketingConsent: boolean;
  notes?: string;
  tags?: string[];
  createdAt?: string;
}

export interface SanitizedBuyerData {
  id: string;
  preferredLocation: string;
  preferredState: string;
  propertyType: string;
  budgetMin: number;
  budgetMax: number;
  bedroomsNeeded: number;
  purchasePurpose: string;
  buyingTimeline: string;
  hasMarketingConsent: boolean;
  // Notice: fullName, email, phone are deliberately excluded for PDPA compliance
}
