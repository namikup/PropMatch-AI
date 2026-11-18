import { AIRequestValidator } from "../src/validators/ai_request_validator";
import { HttpsError } from "firebase-functions/v2/https";

describe("AIRequestValidator", () => {
  const callerUid = "agent_abc_123";

  describe("validateAuth", () => {
    it("should return callerUid when authenticated", () => {
      expect(AIRequestValidator.validateAuth(callerUid)).toBe(callerUid);
    });

    it("should throw unauthenticated when uid is missing or empty", () => {
      expect(() => AIRequestValidator.validateAuth(undefined)).toThrow(HttpsError);
      expect(() => AIRequestValidator.validateAuth("")).toThrow(HttpsError);
    });
  });

  describe("validateProject", () => {
    const validProject = {
      id: "proj_001",
      ownerId: callerUid,
      name: "The Tamarind Luxury Suites",
      developer: "E&O Berhad",
      location: "Seri Tanjung Pinang",
      state: "Penang",
      propertyType: "Condominium",
      startingPrice: 750000,
      maximumPrice: 1200000,
      bedrooms: 3,
      bathrooms: 2,
      builtUpArea: 1048,
      facilities: ["Infinity Pool", "Gymnasium"],
      nearbyAmenities: ["Lotus's", "Straits Quay"],
      description: "Exclusive seafront condominium with resort facilities.",
      purpose: "Own Stay & Investment",
      status: "Completed"
    };

    it("should accept valid project belonging to caller", () => {
      const result = AIRequestValidator.validateProject(validProject, callerUid);
      expect(result.id).toBe("proj_001");
      expect(result.ownerId).toBe(callerUid);
      expect(result.name).toBe("The Tamarind Luxury Suites");
    });

    it("should throw permission-denied when project belongs to another agent", () => {
      const foreignProject = { ...validProject, ownerId: "agent_xyz_999" };
      expect(() => AIRequestValidator.validateProject(foreignProject, callerUid)).toThrow(
        expect.objectContaining({ code: "permission-denied" })
      );
    });

    it("should throw invalid-argument when project data is missing", () => {
      expect(() => AIRequestValidator.validateProject(null, callerUid)).toThrow(
        expect.objectContaining({ code: "invalid-argument" })
      );
      expect(() => AIRequestValidator.validateProject({ ownerId: callerUid }, callerUid)).toThrow(
        expect.objectContaining({ code: "invalid-argument" })
      );
    });

    it("should truncate overly long descriptions to prevent prompt bloat", () => {
      const longDesc = "A".repeat(5000);
      const projectWithLongDesc = { ...validProject, description: longDesc };
      const result = AIRequestValidator.validateProject(projectWithLongDesc, callerUid);
      expect(result.description.length).toBe(3000);
    });
  });

  describe("validateAndSanitizeBuyers", () => {
    it("should sanitize PII from buyer records for PDPA compliance", () => {
      const rawBuyers = [
        {
          id: "buyer_001",
          ownerId: callerUid,
          fullName: "Tan Ah Kow", // PII to be removed
          email: "tan.ahkow@example.com", // PII to be removed
          phone: "+60123456789", // PII to be removed
          preferredLocation: "Bayan Lepas",
          preferredState: "Penang",
          propertyType: "Condominium",
          budgetMin: 500000,
          budgetMax: 700000,
          bedroomsNeeded: 3,
          purchasePurpose: "Own Stay",
          buyingTimeline: "Within 3 months",
          hasMarketingConsent: true
        }
      ];

      const sanitized = AIRequestValidator.validateAndSanitizeBuyers(rawBuyers, callerUid);
      expect(sanitized.length).toBe(1);
      expect(sanitized[0].id).toBe("buyer_001");
      expect(sanitized[0].preferredLocation).toBe("Bayan Lepas");
      expect((sanitized[0] as any).fullName).toBeUndefined();
      expect((sanitized[0] as any).email).toBeUndefined();
      expect((sanitized[0] as any).phone).toBeUndefined();
    });

    it("should throw permission-denied when buyer belongs to another agent", () => {
      const foreignBuyers = [
        {
          id: "buyer_foreign",
          ownerId: "agent_other",
          preferredLocation: "Penang"
        }
      ];

      expect(() => AIRequestValidator.validateAndSanitizeBuyers(foreignBuyers, callerUid)).toThrow(
        expect.objectContaining({ code: "permission-denied" })
      );
    });

    it("should reject batch matching requests exceeding 50 buyers", () => {
      const largeBatch = Array.from({ length: 51 }, (_, i) => ({
        id: `buyer_${i}`,
        ownerId: callerUid,
        preferredLocation: "KL"
      }));

      expect(() => AIRequestValidator.validateAndSanitizeBuyers(largeBatch, callerUid)).toThrow(
        expect.objectContaining({ code: "invalid-argument" })
      );
    });
  });
});
